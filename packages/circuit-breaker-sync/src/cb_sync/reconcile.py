"""The reconciliation engine.

Given an :class:`~cb_sync.inventory.Inventory` and a live Circuit Breaker
server, compute and (optionally) apply the minimal set of API calls that makes
the *flake-owned* part of the server match the inventory.

Safety properties (all covered by tests):

* only entities carrying our ``nix:`` ownership mark are ever modified;
* updates are narrow ``PATCH``es of drifted *managed* fields; create-only fields
  (names, notes, ...) and foreign tags are never overwritten;
* nothing is deleted by default - a vanished resource is only tagged
  ``nix:retired`` (and its monitors paused);
* canvas layout is never touched;
* a second run with unchanged input performs zero writes;
* an unusable inventory (empty, or shrunk past a threshold) aborts before any
  write.
"""

from __future__ import annotations

import datetime as dt
import fnmatch
import re
from dataclasses import dataclass, field
from typing import Any, Callable

from . import adapter
from .adapter import (
    TAG_ID_PREFIX,
    TAG_MANAGED,
    TAG_PREFIX,
    TAG_RETIRED,
    Desired,
    Link,
)
from .client import (
    AmbiguousWrite,
    ApiError,
    AuthError,
    Client,
    Conflict,
    NotFound,
    TransientError,
)
from .inventory import Inventory
from .policy import Policy
from .state import State

KIND_PATHS: dict[str, tuple[str, str]] = {
    "network": ("/api/v1/networks", "/api/v1/networks/{id}"),
    "hardware": ("/api/v1/hardware", "/api/v1/hardware/{id}"),
    "compute": ("/api/v1/compute-units", "/api/v1/compute-units/{id}"),
    "service": ("/api/v1/services", "/api/v1/services/{id}"),
    "monitor": ("/api/v1/monitors", "/api/v1/monitors/{id}"),
    "discovery": ("/api/v1/discovery/profiles", "/api/v1/discovery/profiles/{id}"),
}
TAGGED_KINDS = ("network", "hardware", "compute", "service")
WRITE_ACTIONS = frozenset({"create", "update", "adopt", "retire", "unretire", "delete", "link", "unlink"})


class SafetyGuard(Exception):
    """The inventory failed a pre-flight safety check (exit code 7)."""


class Incompatible(Exception):
    """The server is not something this adapter can talk to (exit code 6)."""


@dataclass
class Op:
    action: str   # create|update|adopt|retire|unretire|delete|link|unlink|skip|noop|drift|error
    kind: str
    key: str
    detail: dict[str, Any] = field(default_factory=dict)
    cb_id: int | None = None
    error: str | None = None

    def to_dict(self) -> dict[str, Any]:
        d: dict[str, Any] = {"action": self.action, "kind": self.kind, "key": self.key}
        if self.cb_id is not None:
            d["id"] = self.cb_id
        if self.detail:
            d["detail"] = self.detail
        if self.error:
            d["error"] = self.error
        return d


@dataclass
class Report:
    applied: bool
    ops: list[Op] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)
    server_version: str | None = None
    api_calls: int = 0

    @property
    def errors(self) -> list[Op]:
        return [o for o in self.ops if o.action == "error"]

    @property
    def changes(self) -> list[Op]:
        return [o for o in self.ops if o.action in WRITE_ACTIONS]

    def counts(self) -> dict[str, int]:
        out: dict[str, int] = {}
        for o in self.ops:
            out[o.action] = out.get(o.action, 0) + 1
        return dict(sorted(out.items()))

    def to_dict(self) -> dict[str, Any]:
        return {
            "applied": self.applied,
            "serverVersion": self.server_version,
            "apiCalls": self.api_calls,
            "counts": self.counts(),
            "changes": len(self.changes),
            "errors": len(self.errors),
            "warnings": self.warnings,
            "operations": [o.to_dict() for o in self.ops if o.action != "noop"],
        }


# --------------------------------------------------------------------------
# Value normalisation for drift detection
# --------------------------------------------------------------------------


def _norm(name: str, value: Any) -> Any:
    if value == "" or value is None:
        return None
    if name == "ports" and isinstance(value, list):
        return sorted((int(p.get("port") or 0), str(p.get("protocol") or "tcp")) for p in value if isinstance(p, dict))
    if name == "scan_types" and isinstance(value, list):
        return sorted(str(v) for v in value)
    if name == "config" and isinstance(value, dict):
        return {k: _norm("", v) for k, v in sorted(value.items())}
    if isinstance(value, list):
        return list(value)
    return value


def _ports_payload(ports: list[dict[str, Any]]) -> list[dict[str, Any]]:
    return [{"port": p["port"], "protocol": p.get("protocol", "tcp"), "label": p.get("label")} for p in ports]


def _diff(current: dict[str, Any], wanted: dict[str, Any]) -> dict[str, Any]:
    return {k: v for k, v in wanted.items() if _norm(k, current.get(k)) != _norm(k, v)}


def _clean(payload: dict[str, Any]) -> dict[str, Any]:
    return {k: v for k, v in payload.items() if v is not None}


def _now_iso(now: Callable[[], dt.datetime]) -> str:
    return now().astimezone(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


# --------------------------------------------------------------------------
# Server compatibility
# --------------------------------------------------------------------------


@dataclass
class ServerInfo:
    version: str | None
    warnings: list[str]


def check_server(client: Client, *, tested: str, allow_untested: bool = False) -> ServerInfo:
    """Verify API shape (OpenAPI) and version drift before any write."""
    warnings: list[str] = []
    try:
        doc = client.get("/api/openapi.json")
    except NotFound as exc:
        raise Incompatible("server does not publish /api/openapi.json; cannot verify API compatibility") from exc
    if not isinstance(doc, dict):
        raise Incompatible("server returned a non-JSON OpenAPI document")
    problems = adapter.check_openapi(doc)
    if problems:
        raise Incompatible("API incompatible with this adapter: " + "; ".join(problems[:8]))
    version = str((doc.get("info") or {}).get("version") or "") or None
    if version is None:
        warnings.append("server did not report a version")
    elif version != tested:
        same_minor = version.split(".")[:2] == tested.split(".")[:2]
        msg = f"Circuit Breaker {version} differs from the tested {tested}"
        if not same_minor and not allow_untested:
            raise Incompatible(msg + " (the /api/v1 API is not stable across releases; use --allow-untested to override)")
        warnings.append(msg + (" (same minor series; proceeding)" if same_minor else " (--allow-untested)"))
    return ServerInfo(version, warnings)


# --------------------------------------------------------------------------
# Engine
# --------------------------------------------------------------------------


class Reconciler:
    MAX_CONSECUTIVE_TRANSIENT = 3

    def __init__(
        self,
        client: Client,
        inv: Inventory,
        policy: Policy,
        state: State,
        *,
        apply: bool,
        now: Callable[[], dt.datetime] = lambda: dt.datetime.now(dt.timezone.utc),
    ) -> None:
        self.c = client
        self.inv = inv
        self.policy = policy
        self.state = state
        self.apply = apply
        self.now = now
        self.report = Report(applied=apply)
        self.cbid: dict[str, int] = {}
        self.managed: dict[str, dict[str, dict[str, Any]]] = {k: {} for k in KIND_PATHS}
        self.unmanaged: dict[str, list[dict[str, Any]]] = {k: [] for k in KIND_PATHS}
        self.failed: set[str] = set()
        self._placeholder = 0
        self._transient_streak = 0
        self._agents: list[dict[str, Any]] | None = None
        self.desired: list[Desired] = []

    # -- plumbing ------------------------------------------------------------
    def _record(self, action: str, kind: str, key: str, cb_id: int | None = None, **detail: Any) -> Op:
        op = Op(action, kind, key, detail, cb_id)
        self.report.ops.append(op)
        return op

    def _fail(self, kind: str, key: str, exc: Exception) -> None:
        self.failed.add(key)
        self.report.ops.append(Op("error", kind, key, error=str(exc)))

    def _guard_call(self, fn: Callable[[], Any]) -> Any:
        """Run an API call; AuthError aborts the run, repeated transient errors too."""
        try:
            result = fn()
            self._transient_streak = 0
            return result
        except TransientError:
            self._transient_streak += 1
            if self._transient_streak >= self.MAX_CONSECUTIVE_TRANSIENT:
                raise
            raise

    def _next_placeholder(self) -> int:
        self._placeholder -= 1
        return self._placeholder

    # -- snapshot --------------------------------------------------------------
    def snapshot(self) -> None:
        for kind, (list_path, _) in KIND_PATHS.items():
            if kind == "monitor" and not self.policy.sync_monitors:
                continue
            if kind == "discovery" and not (self.policy.discovery or self._has_managed_profiles_hint()):
                # Still list: we must be able to disable profiles we created earlier.
                pass
            items = self.c.get(list_path) or []
            self._index(kind, items)

    def _has_managed_profiles_hint(self) -> bool:
        return True

    def _index(self, kind: str, items: list[dict[str, Any]]) -> None:
        self.managed[kind] = {}
        self.unmanaged[kind] = []
        for e in sorted(items, key=lambda x: x.get("id", 0)):
            key = self._owner_key(kind, e)
            if key is None:
                self.unmanaged[kind].append(e)
                continue
            if key in self.managed[kind]:
                self.report.warnings.append(
                    f"duplicate {kind} entities carry {key}: using id {self.managed[kind][key]['id']}, ignoring id {e['id']}"
                )
                continue
            self.managed[kind][key] = e
            self.cbid[key] = e["id"]

    @staticmethod
    def _owner_key(kind: str, e: dict[str, Any]) -> str | None:
        if kind in TAGGED_KINDS:
            return adapter.owner_id_from_tags(e.get("tags"))
        if kind == "monitor":
            return adapter.monitor_owner_id(e.get("name"))
        if kind == "discovery":
            name = e.get("name") or ""
            return f"discovery:{name[len(adapter.PROFILE_PREFIX):]}" if name.startswith(adapter.PROFILE_PREFIX) else None
        return None

    # -- main ------------------------------------------------------------------
    def run(self) -> Report:
        self.desired = adapter.build_desired(self.inv, self.policy)
        self.snapshot()
        for d in self.desired:
            if self._aborted():
                break
            self._reconcile_item(d)
        desired_keys = {d.key for d in self.desired}
        link_keys = {d.key for d in self.desired if d.skip is None}
        self._reconcile_links(adapter.build_links(self.inv, link_keys))
        if self.report.errors:
            self.report.warnings.append("retirement deferred: this run had errors")
        else:
            self._retire(desired_keys)
        return self.report

    def _aborted(self) -> bool:
        return self._transient_streak >= self.MAX_CONSECUTIVE_TRANSIENT

    # -- per item ----------------------------------------------------------------
    def _reconcile_item(self, d: Desired) -> None:
        if d.skip:
            self._record("skip", d.kind, d.key, reason=d.skip)
            return
        try:
            if d.kind in TAGGED_KINDS:
                self._reconcile_tagged(d)
            elif d.kind == "monitor":
                self._reconcile_monitor(d)
            elif d.kind == "discovery":
                self._reconcile_discovery(d)
        except AuthError:
            raise
        except (ApiError, KeyError) as exc:
            if isinstance(exc, TransientError):
                self._transient_streak += 1
            self._fail(d.kind, d.key, exc)

    def _resolve_refs(self, d: Desired) -> dict[str, int] | None:
        out: dict[str, int] = {}
        for api_field, target in d.refs.items():
            if target in self.failed or target not in self.cbid:
                self._record("skip", d.kind, d.key, reason=f"dependency {target} is not available")
                return None
            out[api_field] = self.cbid[target]
        return out

    # IP-conflict handling ---------------------------------------------------------
    @staticmethod
    def _is_ip_conflict(exc: Conflict) -> bool:
        body = exc.body
        return isinstance(body, dict) and "IP conflict" in str(body.get("detail", ""))

    def _with_ip_fallback(self, d: Desired, payload: dict[str, Any], call: Callable[[dict[str, Any]], Any]) -> Any:
        """Run ``call(payload)``; on an IP-conflict 409 retry without ``ip_address``.

        Circuit Breaker refuses two entities with the same IP. When the flake
        itself declares the same address twice (a real misconfiguration worth
        surfacing) the entity is still created so the topology is complete; the
        conflict is reported and remembered so later runs stay idempotent.
        """
        try:
            return call(payload)
        except Conflict as exc:
            if "ip_address" not in payload or not self._is_ip_conflict(exc):
                raise
            detail = (exc.body or {}).get("detail") if isinstance(exc.body, dict) else None
            conflicts = detail.get("conflicts", []) if isinstance(detail, dict) else []
            others = [c.get("entity_name") for c in conflicts if isinstance(c, dict)]
            self.state.ip_conflicts[d.key] = {"ip": payload["ip_address"], "with": others}
            self.report.warnings.append(
                f"{d.kind} {d.key}: ip_address {payload['ip_address']} is already used by {', '.join(map(str, others)) or 'another entity'}; "
                "synced without it (fix the duplicate address in the flake)"
            )
            rest = {k: v for k, v in payload.items() if k != "ip_address"}
            return call(rest) if rest else None

    def _drop_known_ip_conflict(self, d: Desired, wanted: dict[str, Any]) -> dict[str, Any]:
        known = self.state.ip_conflicts.get(d.key)
        if known and wanted.get("ip_address") == known.get("ip"):
            wanted = {k: v for k, v in wanted.items() if k != "ip_address"}
            self._record("drift", d.kind, d.key, reason=f"ip_address {known['ip']} conflicts with {', '.join(map(str, known.get('with', [])))}")
        elif known:
            self.state.ip_conflicts.pop(d.key, None)  # the declared address changed; try again
        return wanted

    # tagged kinds -----------------------------------------------------------------
    def _reconcile_tagged(self, d: Desired) -> None:
        refs = self._resolve_refs(d)
        if refs is None:
            return
        wanted = {**d.managed, **refs}
        if "ports" in wanted:
            wanted["ports"] = _ports_payload(wanted["ports"])
        wanted = self._drop_known_ip_conflict(d, wanted)
        cur = self.managed[d.kind].get(d.key)
        if cur is None:
            cand = self._adoption_candidate(d)
            if cand == "ambiguous":
                self.report.warnings.append(
                    f"{d.kind} {d.key}: several unmanaged entities match; not adopting and not creating a duplicate"
                )
                self._record("skip", d.kind, d.key, reason="ambiguous adoption match")
                self.failed.add(d.key)
                return
            if isinstance(cand, dict):
                self._adopt(d, cand, wanted)
            else:
                self._create_tagged(d, wanted)
            return
        self._update_tagged(d, cur, wanted)

    def _adoption_candidate(self, d: Desired) -> dict[str, Any] | str | None:
        keys = self.policy.adopt
        matches: dict[int, dict[str, Any]] = {}
        for e in self.unmanaged[d.kind]:
            hit = False
            if "name" in keys and (e.get("name") or "").casefold() in {n.casefold() for n in d.match_names if n}:
                hit = True
            if "ip" in keys and d.match_ip and e.get("ip_address") == d.match_ip and d.kind in ("hardware", "compute"):
                hit = True
            if "mac" in keys and d.match_mac and (e.get("mac_address") or "").lower() == d.match_mac.lower():
                hit = True
            if "cidr" in keys and d.match_cidr and (e.get("cidr") or "") == d.match_cidr and d.kind == "network":
                hit = True
            if hit:
                matches[e["id"]] = e
        if not matches:
            return None
        if len(matches) > 1:
            return "ambiguous"
        return next(iter(matches.values()))

    def _create_tagged(self, d: Desired, wanted: dict[str, Any]) -> None:
        payload = _clean({**d.create, **wanted})
        if "ip_address" not in wanted:
            payload.pop("ip_address", None)
        if "ports" in d.create and "ports" in wanted:
            payload["ports"] = wanted["ports"]
        payload["tags"] = adapter.merge_tags([], d.tags)
        list_path, _ = KIND_PATHS[d.kind]
        if not self.apply:
            pid = self._next_placeholder()
            self.cbid[d.key] = pid
            self._record("create", d.kind, d.key, cb_id=None, fields=sorted(payload))
            return
        try:
            created = self._guard_call(lambda: self._with_ip_fallback(d, payload, lambda p: self.c.post(list_path, p)))
        except AmbiguousWrite:
            created = self._recover_create(d)
            if created is None:
                # Not there: safe to retry once. The tag makes a later retry idempotent.
                created = self._guard_call(lambda: self._with_ip_fallback(d, payload, lambda p: self.c.post(list_path, p)))
        self.cbid[d.key] = created["id"]
        self.managed[d.kind][d.key] = created
        self.state.entities[d.key] = {"kind": d.kind, "id": created["id"]}
        self._record("create", d.kind, d.key, cb_id=created["id"], fields=sorted(payload))

    def _recover_create(self, d: Desired) -> dict[str, Any] | None:
        """After an ambiguous create, look for the entity by its ownership tag."""
        items = self.c.get(KIND_PATHS[d.kind][0]) or []
        for e in items:
            if adapter.owner_id_from_tags(e.get("tags")) == d.key:
                return e
        return None

    def _adopt(self, d: Desired, cand: dict[str, Any], wanted: dict[str, Any]) -> None:
        changes = _diff(cand, wanted)
        changes["tags"] = adapter.merge_tags(list(cand.get("tags") or []), d.tags)
        self.unmanaged[d.kind] = [e for e in self.unmanaged[d.kind] if e["id"] != cand["id"]]
        self.cbid[d.key] = cand["id"]
        if self.apply:
            _, item = KIND_PATHS[d.kind]
            updated = self._guard_call(lambda: self._with_ip_fallback(d, changes, lambda p: self.c.patch(item.format(id=cand["id"]), p)))
            self.managed[d.kind][d.key] = updated if isinstance(updated, dict) else {**cand, **changes}
            self.state.entities[d.key] = {"kind": d.kind, "id": cand["id"]}
        self._record("adopt", d.kind, d.key, cb_id=cand["id"], name=cand.get("name"), fields=sorted(changes))

    def _update_tagged(self, d: Desired, cur: dict[str, Any], wanted: dict[str, Any]) -> None:
        changes = _diff(cur, wanted)
        existing_tags = list(cur.get("tags") or [])
        retired = TAG_RETIRED in existing_tags
        new_tags = adapter.merge_tags(existing_tags, d.tags)
        if sorted(new_tags) != sorted(existing_tags):
            changes["tags"] = new_tags
        if not changes:
            self._record("noop", d.kind, d.key, cb_id=cur["id"])
            return
        if self.apply:
            _, item = KIND_PATHS[d.kind]
            updated = self._guard_call(lambda: self._with_ip_fallback(d, changes, lambda p: self.c.patch(item.format(id=cur["id"]), p)))
            if updated is None:  # the only drift was an address that conflicts with another entity
                self._record("drift", d.kind, d.key, reason="ip_address conflicts with another entity")
                return
            self.managed[d.kind][d.key] = updated if isinstance(updated, dict) else {**cur, **changes}
        if retired and "tags" in changes:
            self.state.retired_since.pop(d.key, None)
        action = "unretire" if retired and TAG_RETIRED not in changes.get("tags", [TAG_RETIRED]) else "update"
        self._record(action, d.kind, d.key, cb_id=cur["id"], fields=sorted(changes), changes=_summ(cur, changes))

    # monitors ----------------------------------------------------------------------
    def _agent_id(self, name: str) -> int | None:
        if self._agents is None:
            self._agents = self.c.get("/api/v1/agents") or []
        for a in self._agents:
            names = {str(a.get("name") or "").casefold(), str(a.get("hostname") or "").casefold()}
            if name.casefold() in names and str(a.get("status")) == "active":
                return a["id"]
        return None

    def _reconcile_monitor(self, d: Desired) -> None:
        refs = self._resolve_refs(d)
        if refs is None:
            return
        wanted = {**d.managed, **refs, "probe_agent_id": None}  # the flake owns the vantage
        if d.probe_agent:
            agent = self._agent_id(d.probe_agent)
            if agent is None:
                self.report.warnings.append(
                    f"monitor {d.key}: probe agent {d.probe_agent!r} is not enrolled and approved; skipping (not falling back to the server vantage)"
                )
                self._record("skip", "monitor", d.key, reason=f"probe agent {d.probe_agent} unavailable")
                return
            wanted["probe_agent_id"] = agent
        cur = self.managed["monitor"].get(d.key)
        if cur is None:
            payload = _clean({**d.create, **refs, "probe_agent_id": wanted["probe_agent_id"]})
            if not self.apply:
                self.cbid[d.key] = self._next_placeholder()
                self._record("create", "monitor", d.key, fields=sorted(payload))
                return
            try:
                created = self._guard_call(lambda: self.c.post("/api/v1/monitors", payload))
            except AmbiguousWrite:
                created = self._recover_monitor(d.key)
                if created is None:
                    created = self._guard_call(lambda: self.c.post("/api/v1/monitors", payload))
            self.cbid[d.key] = created["id"]
            self.managed["monitor"][d.key] = created
            self._record("create", "monitor", d.key, cb_id=created["id"], fields=sorted(payload))
            return
        changes = _diff(cur, wanted)
        if d.key in self.state.retired_since and not cur.get("enabled", True):
            changes["enabled"] = True
        if not changes:
            self._record("noop", "monitor", d.key, cb_id=cur["id"])
            return
        if self.apply:
            updated = self._guard_call(lambda: self.c.patch(f"/api/v1/monitors/{cur['id']}", changes))
            self.managed["monitor"][d.key] = updated if isinstance(updated, dict) else {**cur, **changes}
            if changes.get("enabled"):
                self.state.retired_since.pop(d.key, None)
        self._record("update", "monitor", d.key, cb_id=cur["id"], fields=sorted(changes), changes=_summ(cur, changes))

    def _recover_monitor(self, key: str) -> dict[str, Any] | None:
        for e in self.c.get("/api/v1/monitors") or []:
            if adapter.monitor_owner_id(e.get("name")) == key:
                return e
        return None

    # discovery -----------------------------------------------------------------------
    def _reconcile_discovery(self, d: Desired) -> None:
        cur = self.managed["discovery"].get(d.key)
        if cur is None:
            if not self.apply:
                self._record("create", "discovery", d.key, fields=sorted(d.create))
                return
            created = self._guard_call(lambda: self.c.post("/api/v1/discovery/profiles", d.create))
            self.managed["discovery"][d.key] = created
            self._record("create", "discovery", d.key, cb_id=created["id"], fields=sorted(d.create))
            return
        changes = _diff(cur, d.managed)
        if not changes:
            self._record("noop", "discovery", d.key, cb_id=cur["id"])
            return
        if self.apply:
            self._guard_call(lambda: self.c.patch(f"/api/v1/discovery/profiles/{cur['id']}", changes))
        self._record("update", "discovery", d.key, cb_id=cur["id"], fields=sorted(changes), changes=_summ(cur, changes))

    # links ------------------------------------------------------------------------------
    def _reconcile_links(self, links: list[Link]) -> None:
        by_kind: dict[str, list[Link]] = {}
        for l in links:
            by_kind.setdefault(l.kind, []).append(l)
        for fn, kind in (
            (self._memberships, "membership"),
            (self._memberships, "membership-compute"),
            (self._dependencies, "dependency"),
            (self._connections, "connection"),
        ):
            try:
                fn(kind, by_kind.get(kind, []))
            except AuthError:
                raise
            except ApiError as exc:
                self._fail("link", kind, exc)

    def _real_id(self, key: str) -> int | None:
        v = self.cbid.get(key)
        return v if isinstance(v, int) and v > 0 else None

    def _memberships(self, kind: str, links: list[Link]) -> None:
        compute = kind == "membership-compute"
        member_path = "members" if compute else "hardware-members"
        member_field = "compute_id" if compute else "hardware_id"
        wanted_by_net: dict[str, dict[str, Link]] = {}
        for l in links:
            wanted_by_net.setdefault(l.b, {})[l.a] = l
        for net_key, wanted in sorted(wanted_by_net.items()):
            if net_key in self.failed or net_key not in self.cbid:
                continue
            net_id = self._real_id(net_key)
            existing: dict[int, dict[str, Any]] = {}
            if net_id is not None:
                for m in self.c.get(f"/api/v1/networks/{net_id}/{member_path}") or []:
                    existing[m[member_field]] = m
            for member_key, link in sorted(wanted.items()):
                if member_key in self.failed or member_key not in self.cbid:
                    continue
                mid = self._real_id(member_key)
                ip = link.get("ip")
                cur = existing.get(mid) if mid is not None else None
                if cur is not None and (cur.get("ip_address") or None) == (ip or None):
                    self._record("noop", "link", link.key)
                    continue
                if cur is not None:
                    # No PATCH exists for memberships; both ends are flake-owned, so replace.
                    if self.apply:
                        self.c.delete(f"/api/v1/networks/{net_id}/{member_path}/{mid}")
                    self._record("unlink", "link", link.key, reason="membership address changed", ip=cur.get("ip_address"))
                if self.apply and net_id is not None and mid is not None:
                    self.c.post(f"/api/v1/networks/{net_id}/{member_path}", _clean({member_field: mid, "ip_address": ip}))
                self._record("link", "link", link.key, network=net_key, member=member_key, ip=ip)
            # stale memberships between two managed entities
            managed_member_ids = {self.cbid[k] for k in self._keys_of_kind("compute" if compute else "hardware")}
            stale = [m for mid, m in existing.items() if mid in managed_member_ids and not any(self._real_id(k) == mid for k in wanted)]
            for m in stale:
                if self.policy.prune_relationships:
                    if self.apply:
                        self.c.delete(f"/api/v1/networks/{net_id}/{member_path}/{m[member_field]}")
                    self._record("unlink", "link", f"{net_key}<-{m[member_field]}", reason="no longer declared")
                else:
                    self._record("drift", "link", f"{net_key}<-{m[member_field]}", reason="membership not declared by the flake (prune_relationships is off)")

    def _keys_of_kind(self, kind: str) -> list[str]:
        return [k for k in self.managed[kind] if k in self.cbid and isinstance(self.cbid[k], int) and self.cbid[k] > 0]

    def _dependencies(self, kind: str, links: list[Link]) -> None:
        by_service: dict[str, list[Link]] = {}
        for l in links:
            by_service.setdefault(l.a, []).append(l)
        for svc_key, wanted in sorted(by_service.items()):
            if svc_key in self.failed or svc_key not in self.cbid:
                continue
            sid = self._real_id(svc_key)
            existing = {d["depends_on_id"] for d in (self.c.get(f"/api/v1/services/{sid}/dependencies") or [])} if sid else set()
            for link in wanted:
                if link.b in self.failed or link.b not in self.cbid:
                    continue
                tid = self._real_id(link.b)
                if tid is not None and tid in existing:
                    self._record("noop", "link", link.key)
                    continue
                if self.apply and sid is not None and tid is not None:
                    try:
                        self.c.post(f"/api/v1/services/{sid}/dependencies", {"depends_on_id": tid})
                    except Conflict:
                        pass  # created concurrently / already present: idempotent
                self._record("link", "link", link.key, service=svc_key, depends_on=link.b)
            if self.policy.prune_relationships and sid is not None:
                wanted_ids = {self._real_id(l.b) for l in wanted}
                managed_ids = {self.cbid[k] for k in self._keys_of_kind("service")}
                for dep in sorted(existing - wanted_ids):
                    if dep in managed_ids:
                        if self.apply:
                            self.c.delete(f"/api/v1/services/{sid}/dependencies/{dep}")
                        self._record("unlink", "link", f"{svc_key}->{dep}", reason="no longer declared")

    def _existing_connections(self) -> dict[tuple[int, int], int]:
        """Hardware connections already on the server, from the topology graph.

        There is no list endpoint for them; the topology graph exposes each as an
        ``e-hh-<id>`` edge between ``hw-<a>`` and ``hw-<b>``.
        """
        found: dict[tuple[int, int], int] = {}
        graph = self.c.get("/api/v1/graph/topology") or {}
        for edge in graph.get("edges", []):
            m = re.fullmatch(r"e-hh-(\d+)", str(edge.get("id", "")))
            s, t = re.fullmatch(r"hw-(\d+)", str(edge.get("source", ""))), re.fullmatch(r"hw-(\d+)", str(edge.get("target", "")))
            if m and s and t:
                found[(int(s.group(1)), int(t.group(1)))] = int(m.group(1))
        return found

    def _connections(self, kind: str, links: list[Link]) -> None:
        # Ids we created are tracked in the state file; if that file is lost the
        # topology graph is consulted so no duplicate connection is created.
        wanted_keys = {l.key for l in links}
        existing: dict[tuple[int, int], int] | None = None
        for link in links:
            if link.a in self.failed or link.b in self.failed:
                continue
            known = self.state.links.get(link.key)
            aid, bid = self._real_id(link.a), self._real_id(link.b)
            if known and known.get("a") == aid and known.get("b") == bid:
                self._record("noop", "link", link.key)
                continue
            if aid is not None and bid is not None and not known:
                if existing is None:
                    existing = self._existing_connections()
                have = existing.get((aid, bid)) or existing.get((bid, aid))
                if have is not None:
                    self.state.links[link.key] = {"a": aid, "b": bid, "id": have}
                    self._record("noop", "link", link.key)
                    continue
            conn_id = None
            if self.apply and aid is not None and bid is not None:
                resp = self.c.post(
                    f"/api/v1/hardware/{aid}/connections",
                    {"target_hardware_id": bid, "connection_type": link.get("connection_type", "ethernet")},
                )
                conn_id = (resp or {}).get("id")
                self.state.links[link.key] = {"a": aid, "b": bid, "id": conn_id}
            self._record("link", "link", link.key, a=link.a, b=link.b, connection=link.get("connection_type"))
        for key, info in sorted(self.state.links.items()):
            if key not in wanted_keys and info.get("id") and self.policy.prune_relationships:
                if self.apply:
                    try:
                        self.c.delete(f"/api/v1/hardware-connections/{info['id']}")
                    except NotFound:
                        pass
                    self.state.links.pop(key, None)
                self._record("unlink", "link", key, reason="no longer declared")

    # retirement ----------------------------------------------------------------------------
    def _retire(self, desired_keys: set[str]) -> None:
        if self.policy.retire == "ignore":
            return
        for kind in ("service", "compute", "hardware", "network", "monitor", "discovery"):
            if kind == "monitor" and not self.policy.sync_monitors:
                continue
            for key, e in sorted(self.managed[kind].items()):
                if key in desired_keys:
                    continue
                try:
                    self._retire_one(kind, key, e)
                except AuthError:
                    raise
                except ApiError as exc:
                    self._fail(kind, key, exc)

    def _retire_one(self, kind: str, key: str, e: dict[str, Any]) -> None:
        _, item = KIND_PATHS[kind]
        stamp = self.state.retired_since.get(key)
        if kind in TAGGED_KINDS:
            tags = list(e.get("tags") or [])
            already = TAG_RETIRED in tags
            if not already:
                new_tags = adapter.merge_tags(tags, [t for t in tags if t.startswith(TAG_PREFIX) and t != TAG_RETIRED], retired=True)
                if self.apply:
                    self._guard_call(lambda: self.c.patch(item.format(id=e["id"]), {"tags": new_tags}))
                    self.state.retired_since[key] = _now_iso(self.now)
                self._record("retire", kind, key, cb_id=e["id"], mode="tag")
                return
            if stamp is None and self.apply:
                self.state.retired_since[key] = _now_iso(self.now)
        elif kind == "monitor":
            if e.get("enabled", True):
                if self.apply:
                    self._guard_call(lambda: self.c.patch(item.format(id=e["id"]), {"enabled": False}))
                    self.state.retired_since[key] = _now_iso(self.now)
                self._record("retire", kind, key, cb_id=e["id"], mode="pause")
                return
            if stamp is None and self.apply:
                self.state.retired_since[key] = _now_iso(self.now)
        elif kind == "discovery":
            if e.get("enabled", True):
                if self.apply:
                    self._guard_call(lambda: self.c.patch(item.format(id=e["id"]), {"enabled": False}))
                self._record("retire", kind, key, cb_id=e["id"], mode="disable")
            return
        # Already retired: maybe past its grace period and deletion is explicitly allowed.
        if self.policy.retire == "delete" and self.policy.allow_delete and stamp:
            since = dt.datetime.strptime(stamp, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=dt.timezone.utc)
            if self.now() - since >= dt.timedelta(days=self.policy.retire_grace_days):
                if self.apply:
                    self._guard_call(lambda: self.c.delete(item.format(id=e["id"])))
                    self.state.retired_since.pop(key, None)
                    self.state.entities.pop(key, None)
                self._record("delete", kind, key, cb_id=e["id"], retired_since=stamp)
                return
        self._record("noop", kind, key, cb_id=e["id"])


def _summ(cur: dict[str, Any], changes: dict[str, Any]) -> dict[str, Any]:
    """Compact before->after summary for the report (no secrets are involved)."""
    out: dict[str, Any] = {}
    for k, v in changes.items():
        if k == "tags":
            before = sorted(t for t in (cur.get("tags") or []) if t.startswith(TAG_PREFIX))
            after = sorted(t for t in v if t.startswith(TAG_PREFIX))
            if before != after:
                out[k] = {"from": before, "to": after}
            continue
        out[k] = {"from": cur.get(k), "to": v}
    return out


def preflight_guard(inv: Inventory, state: State, policy: Policy, *, force: bool = False) -> None:
    """Refuse to apply an inventory that looks like an evaluation failure."""
    hosts = [r for r in inv.resources.values() if r["type"] in ("host", "vm", "device")]
    if not hosts:
        raise SafetyGuard("inventory contains no hosts/VMs/devices; refusing to apply (an empty evaluation must never retire anything)")
    last = state.last_success or {}
    prev = int(last.get("resources") or 0)
    if prev and policy.max_shrink_percent and not force:
        now = len(inv.resources)
        if now < prev * (100 - policy.max_shrink_percent) / 100:
            raise SafetyGuard(
                f"inventory shrank from {prev} to {now} resources (> {policy.max_shrink_percent}%); "
                "refusing to apply. Re-run with --force-shrink if this is intended."
            )


__all__ = [
    "Reconciler",
    "Report",
    "Op",
    "SafetyGuard",
    "Incompatible",
    "check_server",
    "preflight_guard",
    "TAG_MANAGED",
    "TAG_ID_PREFIX",
    "fnmatch",
]
