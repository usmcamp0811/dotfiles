"""Builders for realistic (exporter-shaped) inventory documents."""

from __future__ import annotations

import copy
import json
from pathlib import Path
from typing import Any


def res(rid: str, rtype: str, name: str | None = None, parent: str | None = None, tags: list[str] | None = None, **attrs: Any) -> dict[str, Any]:
    return {
        "id": rid,
        "type": rtype,
        "name": name or rid.split("/", 1)[1],
        "parent": parent,
        "tags": tags or [],
        "attributes": attrs,
        "origin": {"kind": "nixosConfiguration", "ref": rid.split("/", 1)[1]},
        "state": "declared",
    }


def base_inventory() -> dict[str, Any]:
    resources = [
        res("net/lan", "network", "lan", cidr="192.168.50.0/24", vlanId=None, gateway="192.168.50.1"),
        res("net/k8s", "network", "k8s", cidr="192.168.54.0/24", vlanId=40, gateway="192.168.54.1"),
        res("host/router", "host", "router", tags=["role:router", "role:hypervisor"], primaryAddress="192.168.50.1", addressSource="static", hostName="router"),
        res("host/webb", "host", "webb", tags=["role:hypervisor"], primaryAddress="192.168.50.194", addressSource="static", hostName="webb"),
        res("vm/vm-vault", "vm", "vm-vault", parent="host/router", primaryAddress="192.168.50.3", addressSource="dhcp-reservation", vcpu=2, memoryMb=2047, hostName="vm-vault", placement="placed"),
        res("vm/vm-photos", "vm", "vm-photos", parent="host/webb", primaryAddress="192.168.50.12", addressSource="static", vcpu=4, memoryMb=8192, hostName="vm-photos", placement="placed"),
        res("vm/vm-orphan", "vm", "vm-orphan", parent=None, hostName="vm-orphan", placement="unplaced"),
        res("svc/router/ssh", "service", "ssh", parent="host/router", kind="remote-access", address="192.168.50.1", ports=[{"port": 22, "protocol": "tcp", "exposure": "open"}]),
        res("svc/router/traefik", "service", "traefik", parent="host/router", kind="reverse-proxy", address="192.168.50.1", ports=[{"port": 443, "protocol": "tcp", "exposure": "open"}]),
        res("svc/vm-vault/vault", "service", "vault", parent="vm/vm-vault", kind="secrets", address="192.168.50.3", ports=[{"port": 8200, "protocol": "tcp", "exposure": "open"}], publishedHostnames=["vault.lan.example"]),
        res("svc/vm-orphan/ssh", "service", "ssh", parent="vm/vm-orphan", kind="remote-access", ports=[{"port": 22, "protocol": "tcp", "exposure": "open"}]),
        res("device/core-switch", "device", "Core switch", role="switch", primaryAddress="192.168.50.2", addressSource="hint", vendor="ubiquiti"),
    ]
    rels = [
        {"id": "rel/member_of/host/router/net/lan/192.168.50.1", "type": "member_of", "from": "host/router", "to": "net/lan", "attributes": {"address": "192.168.50.1"}, "origin": {"kind": "derived"}},
        {"id": "rel/member_of/host/webb/net/lan/192.168.50.194", "type": "member_of", "from": "host/webb", "to": "net/lan", "attributes": {"address": "192.168.50.194"}, "origin": {"kind": "derived"}},
        {"id": "rel/member_of/vm/vm-vault/net/lan/192.168.50.3", "type": "member_of", "from": "vm/vm-vault", "to": "net/lan", "attributes": {"address": "192.168.50.3"}, "origin": {"kind": "derived"}},
        {"id": "rel/proxies_to/svc/router/traefik/svc/vm-vault/vault/vault", "type": "proxies_to", "from": "svc/router/traefik", "to": "svc/vm-vault/vault", "attributes": {"router": "vault"}, "origin": {"kind": "derived"}},
        {"id": "rel/connects_to/host/router/device/core-switch", "type": "connects_to", "from": "host/router", "to": "device/core-switch", "attributes": {"connection": "ethernet"}, "origin": {"kind": "hint"}},
    ]
    monitors = [
        {"id": "mon/host/router/icmp", "target": "host/router", "checkType": "icmp", "host": "192.168.50.1", "config": {}, "intervalSecs": 60, "name": "router reachability"},
        {"id": "mon/host/router/ssh", "target": "host/router", "checkType": "tcp", "host": "192.168.50.1", "config": {"port": 22}, "intervalSecs": 60, "name": "router ssh"},
        {"id": "mon/svc/vm-vault/vault/http", "target": "svc/vm-vault/vault", "checkType": "http", "host": "vault.lan.example", "config": {"url": "https://vault.lan.example/", "method": "GET", "verify_tls": True, "accepted_statuses": ["200-399"], "follow_redirects": True}, "intervalSecs": 60, "name": "vault https"},
        {"id": "mon/vm/vm-vault/icmp", "target": "vm/vm-vault", "checkType": "icmp", "host": "192.168.50.3", "config": {}, "intervalSecs": 60, "name": "vm-vault reachability"},
    ]
    return {
        "schemaVersion": 1,
        "kind": "circuit-breaker-inventory",
        "semantics": "declared",
        "generator": {"name": "fmf-circuit-breaker-exporter", "version": "1"},
        "source": {"name": "fixture", "revision": "a" * 40},
        "resources": resources,
        "relationships": rels,
        "monitors": monitors,
        "diagnostics": [],
    }


def clone(inv: dict[str, Any]) -> dict[str, Any]:
    return copy.deepcopy(inv)


def write(inv: dict[str, Any], path: Path) -> Path:
    path.write_text(json.dumps(inv))
    return path


def remove_resource(inv: dict[str, Any], rid: str) -> dict[str, Any]:
    """Remove a resource and everything that references it (as the exporter would)."""
    out = clone(inv)
    out["resources"] = [r for r in out["resources"] if r["id"] != rid and r.get("parent") != rid]
    ids = {r["id"] for r in out["resources"]}
    out["relationships"] = [r for r in out["relationships"] if r["from"] in ids and r["to"] in ids]
    out["monitors"] = [m for m in out["monitors"] if m["target"] in ids]
    return out
