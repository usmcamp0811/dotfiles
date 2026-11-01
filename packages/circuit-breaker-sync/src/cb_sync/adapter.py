"""Circuit Breaker v0.4.x API adapter: inventory model -> CB entities.

Everything that is specific to Circuit Breaker's data model lives here:

* how an inventory resource maps to a CB hardware / compute-unit / service /
  network / monitor,
* which fields the flake is authoritative for (``managed``) versus which are
  only used when an entity is first created (``create``) - so humans can rename
  things, edit notes and keep manual metadata,
* how ownership is recorded (tags / name suffix), and
* which API operations and schema fields this adapter requires (checked against
  the server's own OpenAPI document before any write).

Ownership
---------
Circuit Breaker has no external-id field. Ownership is therefore recorded in
tags with the reserved ``nix:`` prefix:

* ``nix:managed``      marker
* ``nix:id:<id>``      stable inventory id (the identity; IPs and names may change)
* ``nix:retired``      the resource disappeared from the flake (non-destructive)

Monitors have no tags; they carry a `` [nix:<id>]`` suffix in their name.
Discovery profiles carry a ``nix:`` name prefix. The reconciler only ever
modifies or retires entities carrying these marks.
"""

from __future__ import annotations

import fnmatch
import re
from dataclasses import dataclass, field
from typing import Any

from .inventory import Inventory
from .policy import Policy

TAG_PREFIX = "nix:"
TAG_MANAGED = "nix:managed"
TAG_ID_PREFIX = "nix:id:"
TAG_RETIRED = "nix:retired"
MONITOR_SUFFIX_RE = re.compile(r"\s\[nix:(?P<id>[^\]]+)\]$")
PROFILE_PREFIX = "nix: "

NOTE_HARDWARE = (
    "Declared in the NixOS flake. Circuit Breaker fields kept in sync by Nix: "
    "IP address, platform. Everything else (name, notes, tags without the 'nix:' prefix, "
    "canvas position) is yours to edit."
)

#: (method, path) pairs this adapter calls. Missing from the server's OpenAPI
#: document => the adapter is incompatible with that server (exit 6).
REQUIRED_OPERATIONS: tuple[tuple[str, str], ...] = (
    ("get", "/api/v1/hardware"),
    ("post", "/api/v1/hardware"),
    ("patch", "/api/v1/hardware/{hardware_id}"),
    ("post", "/api/v1/hardware/{hardware_id}/connections"),
    ("get", "/api/v1/compute-units"),
    ("post", "/api/v1/compute-units"),
    ("patch", "/api/v1/compute-units/{cu_id}"),
    ("get", "/api/v1/services"),
    ("post", "/api/v1/services"),
    ("patch", "/api/v1/services/{service_id}"),
    ("get", "/api/v1/services/{service_id}/dependencies"),
    ("post", "/api/v1/services/{service_id}/dependencies"),
    ("get", "/api/v1/networks"),
    ("post", "/api/v1/networks"),
    ("patch", "/api/v1/networks/{network_id}"),
    ("get", "/api/v1/networks/{network_id}/hardware-members"),
    ("post", "/api/v1/networks/{network_id}/hardware-members"),
    ("get", "/api/v1/networks/{network_id}/members"),
    ("post", "/api/v1/networks/{network_id}/members"),
    ("get", "/api/v1/monitors"),
    ("post", "/api/v1/monitors"),
    ("patch", "/api/v1/monitors/{monitor_id}"),
    ("get", "/api/v1/agents"),
    ("get", "/api/v1/graph/topology"),
    ("get", "/api/v1/discovery/profiles"),
    ("post", "/api/v1/discovery/profiles"),
    ("patch", "/api/v1/discovery/profiles/{profile_id}"),
)

#: schema name -> properties this adapter sends. All must exist server-side.
REQUIRED_FIELDS: dict[str, tuple[str, ...]] = {
    "HardwareCreate": ("name", "role", "ip_address", "software_platform", "location", "notes", "tags"),
    "HardwareUpdate": ("name", "ip_address", "software_platform", "location", "tags"),
    "ComputeUnitCreate": ("name", "kind", "hardware_id", "os", "cpu_cores", "memory_mb", "ip_address", "notes", "tags"),
    "ComputeUnitUpdate": ("hardware_id", "kind", "os", "cpu_cores", "memory_mb", "ip_address", "tags"),
    "ServiceCreate": ("name", "slug", "compute_id", "hardware_id", "category", "url", "ports", "description", "tags"),
    "ServiceUpdate": ("compute_id", "hardware_id", "category", "url", "ports", "tags"),
    "NetworkCreate": ("name", "cidr", "vlan_id", "gateway", "description", "tags"),
    "NetworkUpdate": ("cidr", "vlan_id", "gateway", "tags"),
    "MonitorCreate": ("name", "check_type", "host", "config", "interval_secs", "enabled", "target_type", "target_id", "probe_agent_id"),
    "MonitorUpdate": ("name", "host", "config", "interval_secs", "enabled", "target_type", "target_id", "probe_agent_id"),
    "HardwareNetworkLink": ("hardware_id", "ip_address"),
    "ComputeNetworkLink": ("compute_id", "ip_address"),
    "ServiceDependencyCreate": ("depends_on_id",),
    "DiscoveryProfileCreate": ("name", "cidr", "scan_types", "schedule_cron", "nmap_arguments", "enabled"),
    "DiscoveryProfileUpdate": ("cidr", "scan_types", "schedule_cron", "nmap_arguments", "enabled"),
}


def check_openapi(doc: dict[str, Any]) -> list[str]:
    """Return incompatibilities between this adapter and the server's OpenAPI doc."""
    problems: list[str] = []
    paths = doc.get("paths") or {}
    for method, path in REQUIRED_OPERATIONS:
        if method not in (paths.get(path) or {}):
            problems.append(f"missing operation {method.upper()} {path}")
    schemas = (doc.get("components") or {}).get("schemas") or {}
    for name, fields_ in REQUIRED_FIELDS.items():
        props = (schemas.get(name) or {}).get("properties")
        if props is None:
            problems.append(f"missing schema {name}")
            continue
        for f in fields_:
            if f not in props:
                problems.append(f"schema {name} lacks field {f}")
    return problems


# --------------------------------------------------------------------------
# Ownership helpers
# --------------------------------------------------------------------------


def id_tag(rid: str) -> str:
    return f"{TAG_ID_PREFIX}{rid}"


def owner_id_from_tags(tags: list[str] | None) -> str | None:
    """Return the inventory id recorded in an entity's tags (lowest wins)."""
    ids = sorted(t[len(TAG_ID_PREFIX):] for t in (tags or []) if t.startswith(TAG_ID_PREFIX))
    return ids[0] if ids else None


def monitor_name(display: str, mid: str) -> str:
    return f"{display} [nix:{mid}]"[:200]


def monitor_owner_id(name: str | None) -> str | None:
    m = MONITOR_SUFFIX_RE.search(name or "")
    return m.group("id") if m else None


def merge_tags(existing: list[str], managed: list[str], *, retired: bool = False) -> list[str]:
    """Union of foreign tags (kept verbatim) and the managed ``nix:`` tags."""
    wanted = set(managed)
    if retired:
        wanted.add(TAG_RETIRED)
    keep = [t for t in existing if not t.startswith(TAG_PREFIX)]
    # Preserve the order of tags we do not own; append ours sorted.
    return keep + sorted(wanted)


def slugify(s: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", s.lower()).strip("-")


# --------------------------------------------------------------------------
# Desired state
# --------------------------------------------------------------------------


@dataclass
class Desired:
    key: str                      # inventory id (resource / monitor id / profile name)
    kind: str                     # network|hardware|compute|service|monitor|discovery
    name: str                     # display name used on create
    create: dict[str, Any]        # initial payload (only used when creating)
    managed: dict[str, Any]       # fields the flake is authoritative for
    refs: dict[str, str] = field(default_factory=dict)  # api field -> inventory key to resolve
    tags: list[str] = field(default_factory=list)
    skip: str | None = None       # why this cannot be synced right now
    match_names: tuple[str, ...] = ()
    match_ip: str | None = None
    match_mac: str | None = None
    match_cidr: str | None = None
    probe_agent: str | None = None
    depends: tuple[str, ...] = ()


KIND_ORDER = ("network", "hardware", "compute", "service", "monitor", "discovery")


def _role_for_host(res: dict[str, Any]) -> str:
    tags = set(res.get("tags", []))
    if "role:router" in tags:
        return "router"
    if "role:hypervisor" in tags:
        return "hypervisor"
    return "server"


def _hardware(res: dict[str, Any]) -> Desired:
    a = res.get("attributes", {})
    rid = res["id"]
    is_device = res["type"] == "device"
    managed: dict[str, Any] = {}
    if a.get("primaryAddress"):
        managed["ip_address"] = a["primaryAddress"]
    if not is_device:
        managed["software_platform"] = "NixOS"
    if a.get("location"):
        managed["location"] = a["location"]
    if is_device:
        # Explicit hints on devices are authoritative.
        for src, dst in (("role", "role"), ("vendor", "vendor"), ("model", "model")):
            if a.get(src):
                managed[dst] = a[src]
    create = {
        "name": res["name"],
        "role": a.get("role") if is_device and a.get("role") else _role_for_host(res),
        "ip_address": a.get("primaryAddress"),
        "software_platform": None if is_device else "NixOS",
        "location": a.get("location"),
        "notes": NOTE_HARDWARE,
        "tags": [],
    }
    if is_device:
        create["vendor"] = a.get("vendor")
        create["model"] = a.get("model")
    names = [res["name"]]
    if a.get("hostName"):
        names.append(a["hostName"])
    return Desired(
        key=rid,
        kind="hardware",
        name=res["name"],
        create=create,
        managed=managed,
        tags=_managed_tags(rid, res),
        match_names=tuple(names),
        match_ip=a.get("primaryAddress") if a.get("addressSource") in ("static", "hint") else None,
        match_mac=(a.get("mac") or None),
    )


def _managed_tags(rid: str, res: dict[str, Any]) -> list[str]:
    tags = {TAG_MANAGED, id_tag(rid), f"nix:type:{res['type']}"}
    for t in res.get("tags", []):
        # inventory tags are classifications such as role:router -> nix:role:router
        tags.add(f"nix:{t}")
    return sorted(tags)


def _compute(inv: Inventory, res: dict[str, Any]) -> Desired:
    a = res.get("attributes", {})
    rid = res["id"]
    is_container = res["type"] == "container"
    host = inv.ancestor_host(rid)
    skip = None
    if host is None:
        skip = "no host to place it on (unplaced MicroVM)"
    managed: dict[str, Any] = {"kind": "container" if is_container else "vm", "os": None if is_container else "NixOS"}
    managed = {k: v for k, v in managed.items() if v is not None}
    own_ip = a.get("primaryAddress") or a.get("address")
    host_ip = (inv.resources.get(host or "") or {}).get("attributes", {}).get("primaryAddress")
    # A container that merely publishes ports on its host shares the host's
    # address; Circuit Breaker rejects duplicate IPs, so only record distinct ones.
    if own_ip and not (is_container and own_ip == host_ip):
        managed["ip_address"] = own_ip
    if a.get("vcpu") is not None:
        managed["cpu_cores"] = a["vcpu"]
    if a.get("memoryMb") is not None:
        managed["memory_mb"] = a["memoryMb"]
    create = dict(managed)
    create.update(
        {
            "name": res["name"],
            "notes": NOTE_HARDWARE.replace("IP address, platform", "host, IP address, size"),
            "tags": [],
        }
    )
    return Desired(
        key=rid,
        kind="compute",
        name=res["name"],
        create=create,
        managed=managed,
        refs={"hardware_id": host} if host else {},
        tags=_managed_tags(rid, res),
        skip=skip,
        match_names=(res["name"], a.get("hostName") or res["name"]),
        match_ip=a.get("primaryAddress") if a.get("addressSource") == "static" else None,
        depends=(host,) if host else (),
    )


def _service(inv: Inventory, res: dict[str, Any]) -> Desired:
    a = res.get("attributes", {})
    rid = res["id"]
    parent = res.get("parent")
    parent_res = inv.resources.get(parent or "")
    owner_name = parent_res["name"] if parent_res else "?"
    ports = [
        {"port": p["port"], "protocol": p.get("protocol", "tcp"), "label": a.get("kind")}
        for p in a.get("ports", [])
        if isinstance(p.get("port"), int)
    ]
    published = a.get("publishedHostnames") or []
    url = a.get("url") or (f"https://{published[0]}/" if published else None)
    managed: dict[str, Any] = {"ports": ports}
    if url:
        managed["url"] = url
    refs: dict[str, str] = {}
    skip = None
    if parent_res is None:
        skip = "no owner"
    elif parent_res["type"] == "host":
        refs["hardware_id"] = parent
    elif parent_res["type"] in ("vm",):
        refs["compute_id"] = parent
    else:
        refs["hardware_id"] = inv.ancestor_host(parent) or ""
        if not refs["hardware_id"]:
            skip = "no host to attach to"
            refs = {}
    if parent_res is not None and parent_res["type"] == "vm" and parent_res.get("parent") is None:
        skip = "owner VM is unplaced"
    create = dict(managed)
    create.update(
        {
            "name": f"{res['name']} @ {owner_name}",
            "slug": f"nix-{slugify(rid)}",
            "description": f"{a.get('kind', 'service')} declared in the NixOS flake ({a.get('source', 'inventory')}).",
            "tags": [],
        }
    )
    return Desired(
        key=rid,
        kind="service",
        name=create["name"],
        create=create,
        managed=managed,
        refs=refs,
        tags=_managed_tags(rid, res),
        skip=skip,
        match_names=(create["name"],),
        depends=tuple(refs.values()),
    )


def _network(res: dict[str, Any]) -> Desired:
    a = res.get("attributes", {})
    managed = {k: a[k] for k in ("cidr", "vlanId", "gateway") if a.get(k) is not None}
    if "vlanId" in managed:
        managed["vlan_id"] = managed.pop("vlanId")
    create = dict(managed)
    create.update(
        {
            "name": res["name"],
            "description": a.get("description") or "Network declared in the NixOS flake.",
            "tags": [],
        }
    )
    return Desired(
        key=res["id"],
        kind="network",
        name=res["name"],
        create=create,
        managed=managed,
        tags=_managed_tags(res["id"], res),
        match_names=(res["name"],),
        match_cidr=a.get("cidr"),
    )


def _monitor(inv: Inventory, m: dict[str, Any], policy: Policy) -> Desired:
    target = inv.resources[m["target"]]
    target_kind = {"host": "hardware", "device": "hardware", "vm": "compute_unit", "container": "compute_unit", "service": "service"}[
        target["type"]
    ]
    skip = None
    if target["type"] in ("vm", "container") and inv.ancestor_host(target["id"]) is None:
        skip = "target VM is unplaced"
    if target["type"] == "service":
        owner = inv.resources.get(target.get("parent") or "")
        if owner is not None and owner["type"] == "vm" and owner.get("parent") is None:
            skip = "target service runs on an unplaced VM"
    config = dict(m.get("config", {}))
    managed: dict[str, Any] = {
        "name": monitor_name(m.get("name") or m["id"], m["id"]),
        "check_type": m["checkType"],
        "host": m["host"],
        "config": config,
        "interval_secs": m.get("intervalSecs", 60),
        "target_type": target_kind,
    }
    probe = None
    for pattern, agent in sorted(policy.remote_probes.items()):
        if fnmatch.fnmatchcase(m["id"], pattern) or fnmatch.fnmatchcase(m["target"], pattern):
            probe = agent
            break
    create = dict(managed)
    create["enabled"] = True
    return Desired(
        key=m["id"],
        kind="monitor",
        name=managed["name"],
        create=create,
        managed=managed,
        refs={"target_id": m["target"]},
        skip=skip,
        depends=(m["target"],),
        probe_agent=probe,
    )


def discovery_profile(p: dict[str, Any]) -> Desired:
    name = f"{PROFILE_PREFIX}{p['name']}"
    managed = {
        "cidr": p["cidr"],
        "scan_types": p.get("scan_types", ["nmap"]),
        "schedule_cron": p.get("schedule_cron"),
        "nmap_arguments": p.get("nmap_arguments"),
        "enabled": bool(p.get("enabled", True)),
    }
    create = dict(managed)
    create["name"] = name
    return Desired(key=f"discovery:{p['name']}", kind="discovery", name=name, create=create, managed=managed)


def build_desired(inv: Inventory, policy: Policy) -> list[Desired]:
    """All desired CB entities in dependency order."""
    out: list[Desired] = []
    for rid in sorted(inv.resources):
        res = inv.resources[rid]
        if res["type"] in policy.skip_types:
            continue
        t = res["type"]
        if t == "network":
            out.append(_network(res))
        elif t in ("host", "device"):
            out.append(_hardware(res))
        elif t in ("vm", "container"):
            out.append(_compute(inv, res))
        elif t == "service":
            out.append(_service(inv, res))
    if policy.sync_monitors:
        for m in sorted(inv.monitors, key=lambda x: x["id"]):
            out.append(_monitor(inv, m, policy))
    for p in policy.discovery:
        out.append(discovery_profile(p))
    order = {k: i for i, k in enumerate(KIND_ORDER)}
    out.sort(key=lambda d: order[d.kind])
    # A dependent of a skipped item is skipped too.
    skipped = {d.key for d in out if d.skip}
    changed = True
    while changed:
        changed = False
        for d in out:
            if d.skip is None and any(dep in skipped for dep in d.depends):
                d.skip = "depends on a resource that cannot be synced"
                skipped.add(d.key)
                changed = True
    return out


# --------------------------------------------------------------------------
# Relationships
# --------------------------------------------------------------------------


@dataclass(frozen=True)
class Link:
    kind: str       # membership|membership-compute|dependency|connection
    key: str        # relationship id
    a: str          # inventory key of the owning side
    b: str          # inventory key of the other side
    data: tuple[tuple[str, Any], ...] = ()

    def get(self, name: str, default: Any = None) -> Any:
        return dict(self.data).get(name, default)


def build_links(inv: Inventory, desired_keys: set[str]) -> list[Link]:
    links: list[Link] = []
    seen_pairs: set[tuple[str, str, str]] = set()
    for rel in sorted(inv.relationships, key=lambda r: r["id"]):
        a, b = rel["from"], rel["to"]
        ra, rb = inv.resources[a], inv.resources[b]
        t = rel["type"]
        if t == "member_of" and rb["type"] == "network":
            kind = "membership" if ra["type"] in ("host", "device") else "membership-compute" if ra["type"] in ("vm", "container") else None
            if kind is None or a not in desired_keys or b not in desired_keys:
                continue
            pair = (kind, a, b)
            if pair in seen_pairs:  # CB allows one membership per (member, network)
                continue
            seen_pairs.add(pair)
            links.append(Link(kind, rel["id"], a, b, (("ip", rel.get("attributes", {}).get("address")),)))
        elif t in ("proxies_to", "uses") and ra["type"] == "service" and rb["type"] == "service":
            if a == b or a not in desired_keys or b not in desired_keys:
                continue
            pair = ("dependency", a, b)
            if pair in seen_pairs:
                continue
            seen_pairs.add(pair)
            links.append(Link("dependency", rel["id"], a, b))
        elif t == "connects_to" and ra["type"] in ("host", "device") and rb["type"] in ("host", "device"):
            if a not in desired_keys or b not in desired_keys:
                continue
            links.append(
                Link("connection", rel["id"], a, b, (("connection_type", rel.get("attributes", {}).get("connection", "ethernet")),))
            )
    return links
