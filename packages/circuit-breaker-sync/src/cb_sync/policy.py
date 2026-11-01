"""Reconciler policy: everything an operator may tune, validated in one place."""

from __future__ import annotations

import ipaddress
import json
import re
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

RETIRE_MODES = ("tag", "delete", "ignore")
ADOPT_KEYS = ("name", "ip", "mac", "cidr")
DISCOVERY_SCAN_TYPES = ("nmap", "snmp", "arp", "docker", "agent_connect")
_PRIVATE_NETS = [
    ipaddress.ip_network(n)
    for n in ("10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16", "fc00::/7", "100.64.0.0/10")
]
# Same ceiling the Circuit Breaker agent enforces for a single discovery target.
MAX_DISCOVERY_PREFIX_V4 = 16
MAX_DISCOVERY_PREFIX_V6 = 48
_CRON_RE = re.compile(r"^(\S+\s+){4}\S+$")


class PolicyError(ValueError):
    pass


@dataclass
class Policy:
    #: Which attributes may be used to adopt a pre-existing, unmanaged entity
    #: instead of creating a duplicate.
    adopt: tuple[str, ...] = ("name", "ip", "cidr")
    #: What happens to managed entities that disappear from the inventory.
    #: ``tag`` (default) only marks them ``nix:retired`` and pauses their monitors.
    retire: str = "tag"
    retire_grace_days: int = 30
    allow_delete: bool = False
    #: Remove membership/dependency links between two managed entities when the
    #: inventory no longer declares them. Off by default.
    prune_relationships: bool = False
    #: Abort (exit 7) if the inventory shrank by more than this percentage of
    #: resources versus the last successful sync. 0 disables the check.
    max_shrink_percent: int = 50
    sync_monitors: bool = True
    #: resource-id glob -> agent name. Matching monitors run from that agent's
    #: vantage instead of the server's.
    remote_probes: dict[str, str] = field(default_factory=dict)
    discovery: list[dict[str, Any]] = field(default_factory=list)
    discovery_allow_public: bool = False
    #: Git-driven sync source. ``None`` disables ``sync-git``.
    git: dict[str, Any] | None = None
    #: Resource types to leave out of Circuit Breaker even though they are in the inventory.
    skip_types: tuple[str, ...] = ()

    def validate(self) -> None:
        if self.retire not in RETIRE_MODES:
            raise PolicyError(f"retire must be one of {RETIRE_MODES}")
        bad = [a for a in self.adopt if a not in ADOPT_KEYS]
        if bad:
            raise PolicyError(f"unknown adopt keys {bad}; allowed {ADOPT_KEYS}")
        if self.retire == "delete" and not self.allow_delete:
            raise PolicyError("retire=delete requires allow_delete=true")
        if self.retire_grace_days < 0:
            raise PolicyError("retire_grace_days must be >= 0")
        if not 0 <= self.max_shrink_percent <= 100:
            raise PolicyError("max_shrink_percent must be within 0..100")
        for prof in self.discovery:
            _validate_discovery_profile(prof, allow_public=self.discovery_allow_public)
        if self.git is not None:
            for key in ("url", "ref", "attr"):
                if not isinstance(self.git.get(key), str) or not self.git[key]:
                    raise PolicyError(f"git.{key} must be a non-empty string")
            if not re.match(r"^[A-Za-z0-9._/-]+$", self.git["ref"]):
                raise PolicyError("git.ref contains unsupported characters")
            if not re.match(r"^[A-Za-z0-9._-]+$", self.git["attr"]):
                raise PolicyError("git.attr contains unsupported characters")


def _validate_discovery_profile(prof: dict[str, Any], *, allow_public: bool) -> None:
    name = prof.get("name")
    if not isinstance(name, str) or not name.strip():
        raise PolicyError("discovery profile needs a name")
    cidr = prof.get("cidr")
    if not isinstance(cidr, str):
        raise PolicyError(f"discovery profile {name}: cidr is required (no implicit scanning)")
    try:
        net = ipaddress.ip_network(cidr, strict=False)
    except ValueError as exc:
        raise PolicyError(f"discovery profile {name}: invalid cidr {cidr!r}: {exc}") from exc
    limit = MAX_DISCOVERY_PREFIX_V4 if net.version == 4 else MAX_DISCOVERY_PREFIX_V6
    if net.prefixlen < limit:
        raise PolicyError(
            f"discovery profile {name}: {cidr} is wider than /{limit}; refusing an over-broad scan"
        )
    if net.is_loopback or net.is_link_local or net.is_multicast:
        raise PolicyError(f"discovery profile {name}: {cidr} is a special-use range")
    if not allow_public and not any(net.subnet_of(p) for p in _PRIVATE_NETS if p.version == net.version):
        raise PolicyError(
            f"discovery profile {name}: {cidr} is not a private range "
            "(set discovery_allow_public to scan public space)"
        )
    scan_types = prof.get("scan_types", ["nmap"])
    if not isinstance(scan_types, list) or not scan_types:
        raise PolicyError(f"discovery profile {name}: scan_types must be a non-empty list")
    cron = prof.get("schedule_cron")
    if cron is not None and not (isinstance(cron, str) and _CRON_RE.match(cron.strip())):
        raise PolicyError(f"discovery profile {name}: schedule_cron must be a 5-field cron expression")


def from_dict(data: dict[str, Any] | None) -> Policy:
    data = dict(data or {})
    known = {f for f in Policy.__dataclass_fields__}
    unknown = set(data) - known
    if unknown:
        raise PolicyError(f"unknown policy keys: {sorted(unknown)}")
    if "adopt" in data:
        data["adopt"] = tuple(data["adopt"])
    if "skip_types" in data:
        data["skip_types"] = tuple(data["skip_types"])
    pol = Policy(**data)
    pol.validate()
    return pol


def load(path: str | Path | None) -> Policy:
    if path is None:
        return Policy()
    try:
        data = json.loads(Path(path).read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        raise PolicyError(f"cannot read policy {path}: {exc}") from exc
    if not isinstance(data, dict):
        raise PolicyError("policy must be a JSON object")
    return from_dict(data)
