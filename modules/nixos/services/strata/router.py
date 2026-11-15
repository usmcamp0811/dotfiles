#!/usr/bin/env python3
"""Model-switching front end for several Strata instances (fmf.services.strata.router).

A Strata server holds exactly one model and answers every request with it, whatever "model" the request names. To let a
client choose, one lazy-loading Strata instance is configured per model (each its own systemd unit, on loopback) and
this process sits on the public address:

  * it checks the client's API key (the one key of fmf.services.strata) and answers GET /v1/models with every id;
  * for a request that names a configured model it makes sure that model's unit is the one running: the others are
    stopped first (so the GPU and the pinned RAM are free), then the wanted unit is started and waited for;
  * it forwards the request to that instance, streaming the answer through.

The instances do not see the client's key. They are started with a random key this process writes at start
(backend_key_file, in a directory only the strata user reads) and every forwarded request carries it, so a rotated client
key needs only a restart of this unit, which also stops every instance.

Standard library only. Configuration: one JSON file (argv[1]) written by the NixOS module.
"""

import hmac
import http.client
import json
import os
import secrets
import subprocess
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

CFG = json.load(open(sys.argv[1]))
MODELS = {m["id"]: m for m in CFG["models"]}
DEFAULT = CFG["default"]
HOP = {"connection", "keep-alive", "proxy-authenticate", "proxy-authorization", "te", "trailers", "transfer-encoding", "upgrade"}
# Never forwarded: the client's credentials (the instance has its own), the length (recomputed) and the host.
DROP_REQUEST = HOP | {"host", "authorization", "x-api-key", "content-length"}
DROP_RESPONSE = HOP | {"server", "date"}
AUTH_ERROR = json.dumps({"error": {"type": "authentication_error", "message": "missing or wrong API key"}}).encode()

backend_key = secrets.token_hex(32)


def log(msg):
    print(f"strata-router: {msg}", file=sys.stderr, flush=True)


def systemctl(*args):
    return subprocess.run(
        [CFG["systemctl"], "--no-ask-password", *args], capture_output=True, text=True, timeout=CFG["systemctl_timeout"]
    )


def read_client_key():
    try:
        return open(CFG["key_file"]).read().strip()
    except OSError:
        return ""


def authorized(headers):
    key = read_client_key()
    if len(key) < 32:  # a missing or short key never authenticates anyone
        return False
    auth = headers.get("Authorization", "")
    given = auth[7:] if auth[:7].lower() == "bearer " else headers.get("x-api-key", "")
    return hmac.compare_digest(given.strip().encode(), key.encode())


class Switch:
    """Which model's unit is running, and how many requests are using it. Switching waits for those to finish."""

    def __init__(self):
        self.cond = threading.Condition()
        self.active = None
        self.inflight = 0
        self.switching = False

    def acquire(self, wanted):
        deadline = time.monotonic() + CFG["switch_wait"]
        with self.cond:
            while True:
                if not self.switching and self.active == wanted:
                    self.inflight += 1
                    return
                if not self.switching and self.inflight == 0:
                    self.switching = True
                    break
                left = deadline - time.monotonic()
                if left <= 0:
                    raise Busy(self.active, self.inflight)
                self.cond.wait(left)
        try:
            self.start_only(wanted)
        except BaseException:
            with self.cond:
                self.switching = False
                self.active = None  # unknown: the next request starts from a clean slate
                self.cond.notify_all()
            raise
        with self.cond:
            self.active = wanted
            self.switching = False
            self.inflight += 1
            self.cond.notify_all()

    def release(self):
        with self.cond:
            self.inflight -= 1
            self.cond.notify_all()

    def forget(self, model):
        """The unit of `model` did not answer: do not trust that it is running."""
        with self.cond:
            if self.active == model:
                self.active = None
            self.cond.notify_all()

    def start_only(self, wanted):
        others = [m["unit"] for m in MODELS.values() if m["id"] != wanted]
        started = time.monotonic()
        log(f"switching to {wanted}")
        if others:
            r = systemctl("stop", *others)
            if r.returncode != 0:
                raise Unavailable(f"could not stop the other models: {r.stderr.strip() or r.returncode}")
        r = systemctl("start", MODELS[wanted]["unit"])
        if r.returncode != 0:
            raise Unavailable(f"could not start {MODELS[wanted]['unit']}: {r.stderr.strip() or r.returncode}")
        wait_healthy(MODELS[wanted])
        log(f"{wanted} is up after {time.monotonic() - started:.1f} s")


class Unavailable(Exception):
    pass


class Busy(Exception):
    def __init__(self, active, inflight):
        super().__init__(f"busy with {active} ({inflight} request(s) running)")


def wait_healthy(model):
    deadline = time.monotonic() + CFG["start_timeout"]
    last = "no answer"
    while time.monotonic() < deadline:
        try:
            c = http.client.HTTPConnection("127.0.0.1", model["port"], timeout=5)
            c.request("GET", "/health")
            r = c.getresponse()
            r.read()
            c.close()
            if r.status == 200:
                return
            last = f"/health answered {r.status}"
        except OSError as e:
            last = str(e)
        time.sleep(0.5)
    raise Unavailable(f"{model['unit']} did not become healthy within {CFG['start_timeout']} s ({last})")


SWITCH = Switch()


def choose(method, headers, body):
    """The model a request is for. A request naming nothing known goes to whatever is running (a Strata instance would
    answer it with its own model anyway), or the default when nothing is."""
    if method in ("POST", "PUT") and body:
        try:
            named = json.loads(body).get("model")
        except (ValueError, AttributeError):
            named = None
        if named in MODELS:
            return named
    return SWITCH.active or DEFAULT


class Handler(BaseHTTPRequestHandler):
    # HTTP/1.0: the body of a streamed answer ends when the connection closes, so no chunk framing is needed.
    protocol_version = "HTTP/1.0"
    server_version = "strata-router"

    def log_message(self, fmt, *args):
        pass

    def reply(self, status, body, ctype="application/json"):
        self.send_response(status)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(body)

    def error(self, status, kind, message):
        self.reply(status, json.dumps({"error": {"type": kind, "message": message}}).encode())

    def handle_any(self):
        path = self.path.split("?", 1)[0]
        if path == "/health":
            active = SWITCH.active
            return self.reply(
                200,
                json.dumps(
                    {"status": "ok", "service": "strata", "router": True, "api_key": True, "model": active or DEFAULT,
                     "active": active, "models": sorted(MODELS)}
                ).encode(),
            )
        if not authorized(self.headers):
            return self.reply(401, AUTH_ERROR)
        if self.headers.get("Transfer-Encoding", "").lower() == "chunked":
            return self.error(411, "invalid_request_error", "send a Content-Length (chunked requests are not supported)")
        length = int(self.headers.get("Content-Length") or 0)
        body = self.rfile.read(length) if length else b""
        if path in ("/v1/models", "/models") and self.command in ("GET", "HEAD"):
            data = [{"id": i, "object": "model", "owned_by": "strata"} for i in sorted(MODELS)]
            return self.reply(200, json.dumps({"object": "list", "data": data}).encode())

        model = choose(self.command, self.headers, body)
        try:
            SWITCH.acquire(model)
        except Busy as e:
            self.send_response(503)
            self.send_header("Retry-After", "30")
            self.send_header("Content-Type", "application/json")
            msg = json.dumps({"error": {"type": "overloaded_error", "message": str(e)}}).encode()
            self.send_header("Content-Length", str(len(msg)))
            self.end_headers()
            return self.wfile.write(msg)
        except Unavailable as e:
            log(str(e))
            return self.error(502, "api_error", str(e))
        try:
            self.forward(model, body)
        finally:
            SWITCH.release()

    def forward(self, model, body):
        headers = {k: v for k, v in self.headers.items() if k.lower() not in DROP_REQUEST}
        headers["Authorization"] = f"Bearer {backend_key}"
        headers["Content-Length"] = str(len(body))
        conn = http.client.HTTPConnection("127.0.0.1", MODELS[model]["port"], timeout=CFG["upstream_timeout"])
        try:
            conn.request(self.command, self.path, body=body or None, headers=headers)
            resp = conn.getresponse()
        except OSError as e:
            SWITCH.forget(model)
            log(f"{model}: {e}")
            conn.close()
            return self.error(502, "api_error", f"{model} did not answer: {e}")
        try:
            self.send_response(resp.status)
            for k, v in resp.getheaders():
                if k.lower() not in DROP_RESPONSE:
                    self.send_header(k, v)
            self.send_header("Connection", "close")
            self.end_headers()
            if self.command == "HEAD":
                return
            while True:
                chunk = resp.read1(65536)
                if not chunk:
                    break
                self.wfile.write(chunk)
                self.wfile.flush()
        except (BrokenPipeError, ConnectionResetError):
            pass  # the client left
        except OSError as e:
            log(f"{model}: {e}")
        finally:
            conn.close()

    do_GET = do_POST = do_PUT = do_DELETE = do_PATCH = do_HEAD = do_OPTIONS = handle_any


def main():
    units = [m["unit"] for m in MODELS.values()]
    # Instances left over from before this start hold a key nobody knows any more, and may hold the GPU.
    r = systemctl("stop", *units)
    if r.returncode != 0:
        log(f"warning: could not stop the instances at start: {r.stderr.strip() or r.returncode}")
    path = CFG["backend_key_file"]
    tmp = f"{path}.new"
    fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w") as f:
        f.write(backend_key)
    os.replace(tmp, path)

    ThreadingHTTPServer.daemon_threads = True
    ThreadingHTTPServer.request_queue_size = 64
    server = ThreadingHTTPServer((CFG["listen_host"], CFG["listen_port"]), Handler)
    log(f"listening on {CFG['listen_host']}:{CFG['listen_port']}, models: {', '.join(sorted(MODELS))}, default {DEFAULT}")
    server.serve_forever()


if __name__ == "__main__":
    main()
