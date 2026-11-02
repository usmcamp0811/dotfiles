"""A small in-memory fake of the Circuit Breaker 0.4.x API used by the tests.

It implements only the endpoints the reconciler calls, with the behaviours that
matter for correctness (tag replacement on PATCH, unique service slugs, one
membership per (member, network), 404/409/401 shapes, ...). Failure injection
lets tests simulate rate limits, outages, and writes whose response is lost.

The OpenAPI document served is the real 0.4.6 document trimmed to the
operations/fields this adapter needs (tests/fixtures), so a drift between the
adapter's expectations and upstream is caught by ``check_openapi`` tests.
"""

from __future__ import annotations

import json
import re
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any

FIXTURE = Path(__file__).parent / "fixtures" / "openapi-0.4.6-subset.json"

COLLECTIONS = {
    "hardware": "/api/v1/hardware",
    "compute-units": "/api/v1/compute-units",
    "services": "/api/v1/services",
    "networks": "/api/v1/networks",
    "monitors": "/api/v1/monitors",
    "profiles": "/api/v1/discovery/profiles",
}


class Failure:
    def __init__(self, pattern: str, status: int, times: int, retry_after: str | None, drop: bool, apply_first: bool) -> None:
        self.rx = re.compile(pattern)
        self.status = status
        self.times = times
        self.retry_after = retry_after
        self.drop = drop
        self.apply_first = apply_first


class FakeCB:
    def __init__(self, token: str = "test-token", version: str | None = None) -> None:
        self.token = token
        self.openapi = json.loads(FIXTURE.read_text())
        if version:
            self.openapi["info"]["version"] = version
        self.lock = threading.RLock()
        self.data: dict[str, list[dict[str, Any]]] = {k: [] for k in COLLECTIONS}
        self.next_id: dict[str, int] = {k: 1 for k in COLLECTIONS}
        self.hw_members: dict[int, list[dict[str, Any]]] = {}
        self.cu_members: dict[int, list[dict[str, Any]]] = {}
        self.deps: dict[int, list[dict[str, Any]]] = {}
        self.connections: list[dict[str, Any]] = []
        self.agents: list[dict[str, Any]] = []
        # maps: a map draws only its members; entities created through the API belong to none
        self.maps_api = True
        self.maps: list[dict[str, Any]] = [{"id": 1, "name": "Main", "is_default": True, "sort_order": 0}]
        self.map_nodes: dict[int, list[dict[str, Any]]] = {1: []}
        self.layout: dict[str, Any] = {"nodes": {}}  # canvas positions; the reconciler must never touch it
        self.log: list[tuple[str, str]] = []
        self.failures: list[Failure] = []
        self.requests_seen_auth: list[str | None] = []
        self.httpd: ThreadingHTTPServer | None = None
        self.thread: threading.Thread | None = None

    # -- lifecycle ----------------------------------------------------------
    def start(self) -> "FakeCB":
        fake = self

        class H(BaseHTTPRequestHandler):
            protocol_version = "HTTP/1.1"

            def log_message(self, *a: Any) -> None:  # silence
                return

            def _handle(self) -> None:
                fake._dispatch(self)

            do_GET = do_POST = do_PATCH = do_PUT = do_DELETE = _handle

        self.httpd = ThreadingHTTPServer(("127.0.0.1", 0), H)
        self.thread = threading.Thread(target=self.httpd.serve_forever, kwargs={"poll_interval": 0.01}, daemon=True)
        self.thread.start()
        return self

    def stop(self) -> None:
        if self.httpd:
            self.httpd.shutdown()
            self.httpd.server_close()

    @property
    def url(self) -> str:
        assert self.httpd
        return f"http://127.0.0.1:{self.httpd.server_address[1]}"

    def __enter__(self) -> "FakeCB":
        return self.start()

    def __exit__(self, *exc: Any) -> None:
        self.stop()

    # -- test helpers -----------------------------------------------------------
    def fail(self, pattern: str, status: int = 503, times: int = 1, retry_after: str | None = None) -> None:
        """Answer requests whose "METHOD path" matches ``pattern`` with ``status``."""
        self.failures.append(Failure(pattern, status, times, retry_after, False, False))

    def drop_after_apply(self, pattern: str, times: int = 1) -> None:
        """Apply the request, then close the connection without answering."""
        self.failures.append(Failure(pattern, 0, times, None, True, True))

    def members(self, map_id: int = 1) -> set[tuple[str, int]]:
        return {(n["entity_type"], n["entity_id"]) for n in self.map_nodes.get(map_id, [])}

    @property
    def writes(self) -> list[tuple[str, str]]:
        return [(m, p) for m, p in self.log if m in ("POST", "PATCH", "PUT", "DELETE")]

    def add(self, collection: str, **fields: Any) -> dict[str, Any]:
        with self.lock:
            e = self._new(collection, fields)
            return e

    def find(self, collection: str, **match: Any) -> list[dict[str, Any]]:
        return [e for e in self.data[collection] if all(e.get(k) == v for k, v in match.items())]

    def by_tag(self, collection: str, tag: str) -> list[dict[str, Any]]:
        return [e for e in self.data[collection] if tag in (e.get("tags") or [])]

    # -- entity construction ---------------------------------------------------------
    def _new(self, collection: str, fields: dict[str, Any]) -> dict[str, Any]:
        i = self.next_id[collection]
        self.next_id[collection] += 1
        e: dict[str, Any] = {"id": i}
        if collection in ("hardware", "compute-units", "services", "networks"):
            e.update(name=None, notes=None, tags=[], ip_address=None, created_at="2026-01-01T00:00:00Z")
        if collection == "monitors":
            e.update(
                enabled=True, status="unknown", config={}, interval_secs=60, probe_agent_id=None, target_type=None, target_id=None
            )
        if collection == "profiles":
            e.update(enabled=True, scan_types=["nmap"], managed_by=None, schedule_cron=None, nmap_arguments=None)
        if collection == "hardware":
            e.update(role=None, software_platform=None, location=None, mac_address=None, source=None)
        if collection == "services":
            e.update(slug=None, ports=[], url=None, category=None, compute_id=None, hardware_id=None, description=None)
        if collection == "compute-units":
            e.update(kind=None, hardware_id=None, os=None, cpu_cores=None, memory_mb=None)
        if collection == "networks":
            e.update(cidr=None, vlan_id=None, gateway=None, description=None)
        e.update(fields)
        e["id"] = i
        e["tags"] = sorted(e.get("tags", []) or [], key=str.lower) if "tags" in e else e.get("tags")
        self.data[collection].append(e)
        return e

    # -- HTTP dispatch -------------------------------------------------------------------
    def _dispatch(self, h: BaseHTTPRequestHandler) -> None:
        method = h.command
        path, _, query = h.path.partition("?")
        length = int(h.headers.get("Content-Length") or 0)
        raw = h.rfile.read(length) if length else b""
        body = json.loads(raw) if raw else None
        auth = h.headers.get("Authorization")
        with self.lock:
            self.log.append((method, path))
            self.requests_seen_auth.append(auth)
            sig = f"{method} {path}"
            for f in self.failures:
                if f.times > 0 and f.rx.search(sig):
                    f.times -= 1
                    if f.apply_first:
                        self._route(method, path, query, body, auth)
                    if f.drop:
                        h.close_connection = True
                        h.wfile.flush()
                        h.connection.close()
                        return
                    headers = {"Retry-After": f.retry_after} if f.retry_after else {}
                    self._send(h, f.status, {"detail": "injected failure", "error_code": "SERVICE_NOT_READY"}, headers)
                    return
            status, payload = self._route(method, path, query, body, auth)
        self._send(h, status, payload)

    @staticmethod
    def _send(h: BaseHTTPRequestHandler, status: int, payload: Any, headers: dict[str, str] | None = None) -> None:
        data = b"" if payload is None else json.dumps(payload).encode()
        h.send_response(status)
        h.send_header("Content-Type", "application/json")
        h.send_header("Content-Length", str(len(data)))
        for k, v in (headers or {}).items():
            h.send_header(k, v)
        h.end_headers()
        if data:
            h.wfile.write(data)

    def _route(self, method: str, path: str, query: str, body: Any, auth: str | None) -> tuple[int, Any]:
        if path == "/api/openapi.json":
            return 200, self.openapi
        if auth != f"Bearer {self.token}":
            return 401, {"detail": "Authentication required"}
        # collections
        for name, base in COLLECTIONS.items():
            if path == base:
                if method == "GET":
                    return 200, [dict(e) for e in self.data[name]]
                if method == "POST":
                    return self._create(name, body)
            m = re.fullmatch(re.escape(base) + r"/(\d+)", path)
            if m:
                return self._item(name, int(m.group(1)), method, body)
        m = re.fullmatch(r"/api/v1/networks/(\d+)/(hardware-members|members)", path)
        if m:
            nid, kind = int(m.group(1)), m.group(2)
            store = self.hw_members if kind == "hardware-members" else self.cu_members
            fld = "hardware_id" if kind == "hardware-members" else "compute_id"
            if not self._get("networks", nid):
                return 404, {"detail": "Network not found"}
            if method == "GET":
                return 200, list(store.get(nid, []))
            if method == "POST":
                if any(r[fld] == body[fld] for r in store.get(nid, [])):
                    return 409, {"detail": "already a member"}
                row = {"id": len(store.get(nid, [])) + 1, fld: body[fld], "network_id": nid, "ip_address": body.get("ip_address")}
                store.setdefault(nid, []).append(row)
                return 200, row
        m = re.fullmatch(r"/api/v1/networks/(\d+)/(hardware-members|members)/(\d+)", path)
        if m and method == "DELETE":
            nid, kind, member = int(m.group(1)), m.group(2), int(m.group(3))
            store = self.hw_members if kind == "hardware-members" else self.cu_members
            fld = "hardware_id" if kind == "hardware-members" else "compute_id"
            store[nid] = [r for r in store.get(nid, []) if r[fld] != member]
            return 204, None
        m = re.fullmatch(r"/api/v1/services/(\d+)/dependencies", path)
        if m:
            sid = int(m.group(1))
            if method == "GET":
                return 200, list(self.deps.get(sid, []))
            if method == "POST":
                if any(d["depends_on_id"] == body["depends_on_id"] for d in self.deps.get(sid, [])):
                    return 409, {"detail": "exists"}
                row = {"id": len(self.deps.get(sid, [])) + 1, "service_id": sid, "depends_on_id": body["depends_on_id"]}
                self.deps.setdefault(sid, []).append(row)
                return 201, row
        m = re.fullmatch(r"/api/v1/services/(\d+)/dependencies/(\d+)", path)
        if m and method == "DELETE":
            sid, dep = int(m.group(1)), int(m.group(2))
            self.deps[sid] = [d for d in self.deps.get(sid, []) if d["depends_on_id"] != dep]
            return 204, None
        m = re.fullmatch(r"/api/v1/hardware/(\d+)/connections", path)
        if m and method == "POST":
            row = {"id": len(self.connections) + 1, "source_hardware_id": int(m.group(1)), "target_hardware_id": body["target_hardware_id"]}
            self.connections.append(row)
            return 201, row
        m = re.fullmatch(r"/api/v1/hardware-connections/(\d+)", path)
        if m and method == "DELETE":
            self.connections = [c for c in self.connections if c["id"] != int(m.group(1))]
            return 204, None
        if path.startswith(("/api/v1/maps", "/api/v1/topologies")) and not self.maps_api:
            return 404, {"detail": "Not Found"}
        if path == "/api/v1/maps" and method == "GET":
            return 200, [{**m, "entity_count": len(self.map_nodes.get(m["id"], []))} for m in self.maps]
        m = re.fullmatch(r"/api/v1/topologies/(\d+)", path)
        if m and method == "GET":
            tid = int(m.group(1))
            topo = next((t for t in self.maps if t["id"] == tid), None)
            if topo is None:
                return 404, {"detail": "Topology not found"}
            return 200, {**topo, "nodes": [dict(n) for n in self.map_nodes.get(tid, [])], "edges": []}
        m = re.fullmatch(r"/api/v1/maps/(\d+)/entities", path)
        if m and method == "POST":
            tid = int(m.group(1))
            if not any(t["id"] == tid for t in self.maps):
                return 404, {"detail": f"Map {tid} not found"}
            row = {"entity_type": body["entity_type"], "entity_id": body["entity_id"]}
            if row not in self.map_nodes.setdefault(tid, []):
                self.map_nodes[tid].append(row)
            return 201, {"ok": True}
        m = re.fullmatch(r"/api/v1/maps/(\d+)/entities/([a-z]+)/(\d+)", path)
        if m and method == "DELETE":
            tid, etype, eid = int(m.group(1)), m.group(2), int(m.group(3))
            self.map_nodes[tid] = [n for n in self.map_nodes.get(tid, []) if (n["entity_type"], n["entity_id"]) != (etype, eid)]
            return 204, None
        if path == "/api/v1/agents" and method == "GET":
            return 200, list(self.agents)
        if path == "/api/v1/graph/topology" and method == "GET":
            return 200, {"nodes": [], "edges": [{"id": f"e-hh-{c['id']}", "source": f"hw-{c['source_hardware_id']}", "target": f"hw-{c['target_hardware_id']}", "relation": "connects_to"} for c in self.connections]}
        if path == "/api/v1/graph/layout":
            return (200, self.layout) if method == "GET" else (200, self.layout)
        return 404, {"detail": f"no route {method} {path}"}

    def _ip_conflict(self, ip: str | None, own: tuple[str, int] | None = None) -> tuple[int, Any] | None:
        """Mimic CB's 409 for an IP already used by another hardware/compute entity."""
        if not ip:
            return None
        for coll, kind in (("hardware", "hardware"), ("compute-units", "compute_unit")):
            for e in self.data[coll]:
                if e.get("ip_address") == ip and (coll, e["id"]) != own:
                    return 409, {"detail": {"detail": "IP conflict detected", "conflicts": [{"entity_type": kind, "entity_id": e["id"], "entity_name": e.get("name"), "conflicting_ip": ip}]}}
        return None

    def _get(self, name: str, i: int) -> dict[str, Any] | None:
        return next((e for e in self.data[name] if e["id"] == i), None)

    def _create(self, name: str, body: dict[str, Any]) -> tuple[int, Any]:
        if name == "services":
            slug = body.get("slug")
            if slug and any(e.get("slug") == slug for e in self.data["services"]):
                return 409, {"detail": "A record with this identifier already exists."}
            if not body.get("name"):
                return 422, {"detail": [{"msg": "name required"}]}
        if name == "compute-units" and not self._get("hardware", body.get("hardware_id", -1)):
            return 422, {"detail": "hardware not found"}
        if name == "monitors":
            for key in ("name", "check_type", "host"):
                if not body.get(key):
                    return 422, {"detail": [{"msg": f"{key} required"}]}
        if name in ("hardware", "compute-units"):
            conflict = self._ip_conflict(body.get("ip_address"))
            if conflict:
                return conflict
        e = self._new(name, dict(body))
        return (200 if name in ("monitors", "profiles") else 201), dict(e)

    def _item(self, name: str, i: int, method: str, body: Any) -> tuple[int, Any]:
        e = self._get(name, i)
        if e is None:
            return 404, {"detail": "not found"}
        if method == "GET":
            return 200, dict(e)
        if method == "PATCH":
            if name in ("hardware", "compute-units") and "ip_address" in body:
                conflict = self._ip_conflict(body["ip_address"], (name, i))
                if conflict:
                    return conflict
            for k, v in body.items():
                e[k] = sorted(v, key=str.lower) if k == "tags" else v
            return 200, dict(e)
        if method == "DELETE":
            self.data[name] = [x for x in self.data[name] if x["id"] != i]
            return 204, None
        return 405, {"detail": "method not allowed"}
