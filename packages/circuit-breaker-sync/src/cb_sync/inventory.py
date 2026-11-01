"""Loading and validating the Circuit-Breaker-independent inventory (schema v1).

This module knows nothing about the Circuit Breaker API. It is the contract
between the Nix exporter (``lib/circuit-breaker``) and the reconciler.
"""

from __future__ import annotations

import hashlib
import json
import re
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

SUPPORTED_SCHEMA_VERSIONS = (1,)
KIND = "circuit-breaker-inventory"

RESOURCE_TYPES = frozenset({"host", "vm", "container", "network", "service", "device"})
RELATIONSHIP_TYPES = frozenset(
    {"member_of", "attached_to", "proxies_to", "uses", "mounts_from", "connects_to", "depends_on"}
)
CHECK_TYPES = frozenset({"icmp", "tcp", "http", "dns"})

_ID_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._:@+/-]*$")

# Key names that must never appear anywhere in an inventory. "publicKey" is fine;
# anything that smells like private material is not.
_SECRET_KEY_RE = re.compile(
    r"(pass(word|wd)?$|passphrase|secret|token|private[-_]?key|credential|api[-_]?key|"
    r"auth[-_]?key|preshared|psk$|bearer)",
    re.IGNORECASE,
)
_SECRET_VALUE_RES = (
    re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----"),
    re.compile(r"\bcbe_[A-Za-z0-9_-]{20,}"),
    re.compile(r"\beyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{5,}"),
    re.compile(r"\bAKIA[0-9A-Z]{16}\b"),
)


class InventoryError(Exception):
    """The inventory is malformed or unsupported. Maps to exit code 2 / 6."""

    def __init__(self, message: str, *, incompatible: bool = False) -> None:
        super().__init__(message)
        self.incompatible = incompatible


@dataclass
class Inventory:
    raw: dict[str, Any]
    resources: dict[str, dict[str, Any]] = field(default_factory=dict)
    relationships: list[dict[str, Any]] = field(default_factory=list)
    monitors: list[dict[str, Any]] = field(default_factory=list)
    diagnostics: list[dict[str, Any]] = field(default_factory=list)

    @property
    def revision(self) -> str | None:
        rev = (self.raw.get("source") or {}).get("revision")
        return rev if isinstance(rev, str) and rev else None

    @property
    def digest(self) -> str:
        return digest_of(self.raw)

    def children_of(self, rid: str) -> list[dict[str, Any]]:
        return [r for r in self.resources.values() if r.get("parent") == rid]

    def ancestor_host(self, rid: str) -> str | None:
        """Nearest enclosing ``host`` resource id (a host is its own ancestor host)."""
        seen: set[str] = set()
        cur: str | None = rid
        while cur is not None and cur not in seen:
            seen.add(cur)
            res = self.resources.get(cur)
            if res is None:
                return None
            if res["type"] == "host":
                return cur
            cur = res.get("parent")
        return None


def digest_of(raw: dict[str, Any]) -> str:
    """Stable digest of what the reconciler acts on.

    ``source`` (revision, timestamps) and ``diagnostics`` are deliberately
    excluded: a new commit that does not change the topology must not look like
    a change.
    """
    payload = {
        "schemaVersion": raw.get("schemaVersion"),
        "resources": raw.get("resources", []),
        "relationships": raw.get("relationships", []),
        "monitors": raw.get("monitors", []),
    }
    blob = json.dumps(payload, sort_keys=True, separators=(",", ":"), ensure_ascii=True)
    return hashlib.sha256(blob.encode()).hexdigest()


def load(path: str | Path) -> Inventory:
    """Read, parse, and validate an inventory file."""
    try:
        text = Path(path).read_text(encoding="utf-8")
    except OSError as exc:
        raise InventoryError(f"cannot read inventory {path}: {exc}") from exc
    try:
        raw = json.loads(text)
    except json.JSONDecodeError as exc:
        raise InventoryError(f"inventory {path} is not valid JSON: {exc}") from exc
    return parse(raw)


def parse(raw: Any) -> Inventory:
    errors = validate(raw)
    if errors:
        incompatible = any(e.startswith("schema:") for e in errors)
        shown = "; ".join(errors[:10])
        more = f" (+{len(errors) - 10} more)" if len(errors) > 10 else ""
        raise InventoryError(f"invalid inventory: {shown}{more}", incompatible=incompatible)
    inv = Inventory(raw=raw)
    inv.resources = {r["id"]: r for r in raw["resources"]}
    inv.relationships = list(raw.get("relationships", []))
    inv.monitors = list(raw.get("monitors", []))
    inv.diagnostics = list(raw.get("diagnostics", []))
    return inv


def _scan_for_secrets(value: Any, path: str, errors: list[str]) -> None:
    if isinstance(value, dict):
        for k, v in value.items():
            if isinstance(k, str) and _SECRET_KEY_RE.search(k):
                errors.append(f"secret: key {path}.{k} looks like credential material")
                continue
            _scan_for_secrets(v, f"{path}.{k}", errors)
    elif isinstance(value, list):
        for i, v in enumerate(value):
            _scan_for_secrets(v, f"{path}[{i}]", errors)
    elif isinstance(value, str):
        for rx in _SECRET_VALUE_RES:
            if rx.search(value):
                errors.append(f"secret: value at {path} looks like credential material")
                break


def validate(raw: Any) -> list[str]:
    """Return a list of human-readable problems (empty list == valid)."""
    errors: list[str] = []
    if not isinstance(raw, dict):
        return ["inventory must be a JSON object"]
    if raw.get("kind") != KIND:
        errors.append(f"schema: kind must be {KIND!r}, got {raw.get('kind')!r}")
    version = raw.get("schemaVersion")
    if version not in SUPPORTED_SCHEMA_VERSIONS:
        errors.append(
            f"schema: unsupported schemaVersion {version!r} (supported: {list(SUPPORTED_SCHEMA_VERSIONS)})"
        )
        return errors
    for key in ("resources", "relationships", "monitors"):
        if not isinstance(raw.get(key, []), list):
            errors.append(f"{key} must be a list")
    if errors:
        return errors

    ids: set[str] = set()
    for i, r in enumerate(raw.get("resources", [])):
        where = f"resources[{i}]"
        if not isinstance(r, dict):
            errors.append(f"{where} must be an object")
            continue
        rid = r.get("id")
        if not isinstance(rid, str) or not _ID_RE.match(rid):
            errors.append(f"{where}: invalid id {rid!r}")
            continue
        if rid in ids:
            errors.append(f"{where}: duplicate id {rid}")
        ids.add(rid)
        if r.get("type") not in RESOURCE_TYPES:
            errors.append(f"{rid}: unknown type {r.get('type')!r}")
        if not isinstance(r.get("name"), str) or not r["name"].strip():
            errors.append(f"{rid}: name must be a non-empty string")
        if not isinstance(r.get("attributes", {}), dict):
            errors.append(f"{rid}: attributes must be an object")
        if not isinstance(r.get("tags", []), list):
            errors.append(f"{rid}: tags must be a list")

    for r in raw.get("resources", []):
        if isinstance(r, dict) and r.get("parent") is not None and r["parent"] not in ids:
            errors.append(f"{r.get('id')}: parent {r['parent']!r} is not in the inventory")

    rel_ids: set[str] = set()
    for i, rel in enumerate(raw.get("relationships", [])):
        where = f"relationships[{i}]"
        if not isinstance(rel, dict):
            errors.append(f"{where} must be an object")
            continue
        if rel.get("type") not in RELATIONSHIP_TYPES:
            errors.append(f"{where}: unknown relationship type {rel.get('type')!r}")
        for end in ("from", "to"):
            if rel.get(end) not in ids:
                errors.append(f"{where}: {end} {rel.get(end)!r} is not in the inventory")
        rid = rel.get("id")
        if rid in rel_ids:
            errors.append(f"{where}: duplicate relationship id {rid}")
        rel_ids.add(rid)

    mon_ids: set[str] = set()
    for i, m in enumerate(raw.get("monitors", [])):
        where = f"monitors[{i}]"
        if not isinstance(m, dict):
            errors.append(f"{where} must be an object")
            continue
        mid = m.get("id")
        if not isinstance(mid, str) or not mid:
            errors.append(f"{where}: missing id")
            continue
        if mid in mon_ids:
            errors.append(f"{where}: duplicate monitor id {mid}")
        mon_ids.add(mid)
        if m.get("checkType") not in CHECK_TYPES:
            errors.append(f"{mid}: unsupported checkType {m.get('checkType')!r}")
        if m.get("target") not in ids:
            errors.append(f"{mid}: target {m.get('target')!r} is not in the inventory")
        if not isinstance(m.get("host"), str) or not m.get("host"):
            errors.append(f"{mid}: host must be a non-empty string")
        interval = m.get("intervalSecs", 60)
        if not isinstance(interval, int) or isinstance(interval, bool) or not 10 <= interval <= 86400:
            errors.append(f"{mid}: intervalSecs must be an integer in 10..86400")
        if not isinstance(m.get("config", {}), dict):
            errors.append(f"{mid}: config must be an object")

    _scan_for_secrets(raw.get("resources", []), "resources", errors)
    _scan_for_secrets(raw.get("relationships", []), "relationships", errors)
    _scan_for_secrets(raw.get("monitors", []), "monitors", errors)
    return errors
