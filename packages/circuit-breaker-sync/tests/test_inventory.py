from __future__ import annotations

import json

import pytest

from cb_sync import inventory
from inv_fixtures import base_inventory, clone


def test_valid_inventory_parses():
    inv = inventory.parse(base_inventory())
    assert "host/router" in inv.resources
    assert inv.ancestor_host("svc/vm-vault/vault") == "host/router"
    assert inv.ancestor_host("vm/vm-orphan") is None


def test_unsupported_schema_version_is_incompatible():
    raw = base_inventory()
    raw["schemaVersion"] = 2
    with pytest.raises(inventory.InventoryError) as e:
        inventory.parse(raw)
    assert e.value.incompatible


def test_wrong_kind_rejected():
    raw = base_inventory()
    raw["kind"] = "something-else"
    with pytest.raises(inventory.InventoryError):
        inventory.parse(raw)


def test_duplicate_resource_ids_rejected():
    raw = base_inventory()
    raw["resources"].append(clone(raw["resources"][0]))
    with pytest.raises(inventory.InventoryError, match="duplicate id"):
        inventory.parse(raw)


def test_dangling_parent_and_relationship_and_monitor_rejected():
    raw = base_inventory()
    raw["resources"][4]["parent"] = "host/nope"
    raw["relationships"][0]["to"] = "net/nope"
    raw["monitors"][0]["target"] = "host/nope"
    errors = inventory.validate(raw)
    assert any("parent" in e for e in errors)
    assert any("relationships[0]" in e for e in errors)
    assert any("mon/host/router/icmp" in e for e in errors)


def test_absent_optional_values_are_fine():
    raw = base_inventory()
    for r in raw["resources"]:
        r.pop("tags", None)
        r["attributes"] = {}
    raw.pop("diagnostics")
    raw["source"] = {}
    inv = inventory.parse(raw)
    assert inv.revision is None
    assert inv.diagnostics == []


@pytest.mark.parametrize(
    "key",
    ["password", "wireguardPrivateKey", "apiToken", "secret", "bearer", "credentials", "preshared"],
)
def test_secret_looking_keys_rejected(key):
    raw = base_inventory()
    raw["resources"][2]["attributes"][key] = "x"
    errors = inventory.validate(raw)
    assert any(e.startswith("secret:") for e in errors)


@pytest.mark.parametrize(
    "value",
    [
        "-----BEGIN OPENSSH PRIVATE KEY-----\nabc",
        "cbe_" + "A" * 43,
        "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ4In0.abcdefghij",
    ],
)
def test_secret_looking_values_rejected(value):
    raw = base_inventory()
    raw["resources"][2]["attributes"]["note"] = value
    assert any(e.startswith("secret:") for e in inventory.validate(raw))


def test_public_keys_and_secret_word_in_values_are_allowed():
    raw = base_inventory()
    raw["resources"][2]["attributes"]["publicKey"] = "abc="
    raw["resources"][2]["attributes"]["hostPath"] = "/persist/system/secrets"
    assert inventory.validate(raw) == []


def test_digest_ignores_source_and_diagnostics_but_not_topology():
    a = base_inventory()
    b = clone(a)
    b["source"]["revision"] = "b" * 40
    b["diagnostics"] = [{"level": "info", "code": "x", "subject": "s", "message": "m"}]
    assert inventory.digest_of(a) == inventory.digest_of(b)
    c = clone(a)
    c["resources"][2]["attributes"]["primaryAddress"] = "192.168.50.99"
    assert inventory.digest_of(a) != inventory.digest_of(c)


def test_load_reports_unreadable_and_invalid_json(tmp_path):
    with pytest.raises(inventory.InventoryError, match="cannot read"):
        inventory.load(tmp_path / "missing.json")
    p = tmp_path / "bad.json"
    p.write_text("{not json")
    with pytest.raises(inventory.InventoryError, match="not valid JSON"):
        inventory.load(p)
    p.write_text(json.dumps([1, 2]))
    with pytest.raises(inventory.InventoryError):
        inventory.load(p)
