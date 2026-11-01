from __future__ import annotations

import pytest

from cb_sync.client import AmbiguousWrite, ApiError, AuthError, Client, Conflict, NotFound, TlsConfig, TransientError
from fake_cb import FakeCB


def test_bearer_token_is_sent(cb, client):
    client.get("/api/v1/hardware")
    assert cb.requests_seen_auth[-1] == "Bearer test-token"


def test_error_classification(cb, client):
    with pytest.raises(NotFound):
        client.get("/api/v1/hardware/999")
    cb.add("services", name="a", slug="s")
    with pytest.raises(Conflict):
        client.post("/api/v1/services", {"name": "b", "slug": "s"})
    with pytest.raises(ApiError) as e:
        client.post("/api/v1/services", {"slug": "zzz"})
    assert e.value.status == 422


def test_unauthenticated_openapi_is_allowed_but_api_is_not():
    with FakeCB() as server:
        c = Client(server.url, None, retries=0)
        assert c.get("/api/openapi.json")["info"]["version"] == "0.4.6"
        with pytest.raises(AuthError):
            c.get("/api/v1/hardware")


def test_get_is_retried_on_503_with_backoff(cb):
    sleeps = []
    c = Client(cb.url, cb.token, retries=3, backoff=1.0, sleep=sleeps.append)
    cb.fail(r"GET /api/v1/hardware", status=503, times=2)
    assert c.get("/api/v1/hardware") == []
    assert sleeps == [1.0, 2.0]


def test_retry_after_is_capped(cb):
    sleeps = []
    c = Client(cb.url, cb.token, retries=1, backoff=0.0, sleep=sleeps.append)
    cb.fail(r"GET /api/v1/hardware", status=429, times=1, retry_after="86400")
    c.get("/api/v1/hardware")
    assert max(sleeps) <= 60


def test_retries_are_bounded(cb):
    c = Client(cb.url, cb.token, retries=2, backoff=0.0, sleep=lambda s: None)
    cb.fail(r"GET /api/v1/hardware", status=503, times=100)
    with pytest.raises(TransientError):
        c.get("/api/v1/hardware")
    assert [p for m, p in cb.log].count("/api/v1/hardware") == 3


def test_post_is_not_blindly_retried_after_a_lost_response(cb):
    c = Client(cb.url, cb.token, retries=3, backoff=0.0, sleep=lambda s: None)
    cb.drop_after_apply(r"POST /api/v1/hardware", times=1)
    with pytest.raises(AmbiguousWrite):
        c.post("/api/v1/hardware", {"name": "x"})
    assert len(cb.data["hardware"]) == 1  # applied exactly once; caller must re-read


def test_post_retries_when_server_proves_it_did_not_apply(cb):
    c = Client(cb.url, cb.token, retries=3, backoff=0.0, sleep=lambda s: None)
    cb.fail(r"POST /api/v1/hardware", status=503, times=2)
    c.post("/api/v1/hardware", {"name": "x"})
    assert len(cb.data["hardware"]) == 1


def test_connection_refused_is_transient():
    c = Client("http://127.0.0.1:1", "t", retries=1, backoff=0.0, sleep=lambda s: None, timeout=1)
    with pytest.raises(TransientError):
        c.get("/api/v1/hardware")


def test_invalid_base_url():
    with pytest.raises(ValueError):
        Client("ftp://x", "t")


def test_pin_from_pem_roundtrip(tmp_path):
    import shutil
    import subprocess

    if not shutil.which("openssl"):
        pytest.skip("openssl not available")
    key, crt = tmp_path / "k.pem", tmp_path / "c.pem"
    subprocess.run(
        ["openssl", "req", "-x509", "-newkey", "ec", "-pkeyopt", "ec_paramgen_curve:prime256v1", "-nodes",
         "-keyout", str(key), "-out", str(crt), "-subj", "/CN=localhost", "-days", "1"],
        check=True, capture_output=True,
    )
    cfg = TlsConfig.pin_from_pem_file(crt)
    assert cfg.mode == "pin" and len(cfg.pin_sha256) == 64


def test_tls_pin_accepts_matching_and_rejects_mismatching_certificate(tmp_path):
    import shutil
    import ssl
    import subprocess
    import threading
    from http.server import BaseHTTPRequestHandler, HTTPServer

    if not shutil.which("openssl"):
        pytest.skip("openssl not available")
    key, crt = tmp_path / "k.pem", tmp_path / "c.pem"
    subprocess.run(
        ["openssl", "req", "-x509", "-newkey", "ec", "-pkeyopt", "ec_paramgen_curve:prime256v1", "-nodes",
         "-keyout", str(key), "-out", str(crt), "-subj", "/CN=not-the-hostname", "-days", "1"],
        check=True, capture_output=True,
    )

    class H(BaseHTTPRequestHandler):
        def log_message(self, *a):
            pass

        def do_GET(self):
            body = b'{"ok": true}'
            self.send_response(200)
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

    srv = HTTPServer(("127.0.0.1", 0), H)
    ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    ctx.load_cert_chain(crt, key)
    srv.socket = ctx.wrap_socket(srv.socket, server_side=True)
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    url = f"https://127.0.0.1:{srv.server_address[1]}"
    try:
        good = Client(url, "t", tls=TlsConfig.pin_from_pem_file(crt), retries=0)
        assert good.get("/x") == {"ok": True}
        bad = Client(url, "t", tls=TlsConfig(mode="pin", pin_sha256="0" * 64), retries=0)
        with pytest.raises(ApiError, match="pin mismatch|TLS"):
            bad.get("/x")
        default = Client(url, "t", retries=0)  # system trust must reject a self-signed cert
        with pytest.raises(Exception):
            default.get("/x")
    finally:
        srv.shutdown()
