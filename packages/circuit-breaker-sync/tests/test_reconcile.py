from __future__ import annotations

import datetime as dt

import pytest

from cb_sync import adapter
from cb_sync.client import AuthError, Client, TransientError
from cb_sync.reconcile import Incompatible, SafetyGuard, check_server, preflight_guard
from cb_sync.state import State
from inv_fixtures import base_inventory, clone, remove_resource
from cb_sync import inventory as inv_mod
from cb_sync import policy as policy_mod


def actions(report, action):
    return [o for o in report.ops if o.action == action]


def tagged(cb, coll, rid):
    return cb.by_tag(coll, f"nix:id:{rid}")


# ---------------------------------------------------------------- initial sync
def test_initial_sync_creates_everything_with_ownership_tags(cb, run, inv):
    report = run(inv)
    assert not report.errors
    # networks, hardware (hosts + device), compute (vms), services
    assert len(cb.data["networks"]) == 2
    assert {e["name"] for e in cb.data["hardware"]} == {"router", "webb", "Core switch"}
    assert {e["name"] for e in cb.data["compute-units"]} == {"vm-vault", "vm-photos"}  # vm-orphan is unplaced
    assert len(cb.data["services"]) == 3  # orphan's ssh is skipped
    router = tagged(cb, "hardware", "host/router")[0]
    assert "nix:managed" in router["tags"] and "nix:role:router" in router["tags"]
    assert router["ip_address"] == "192.168.50.1" and router["software_platform"] == "NixOS"
    vault_vm = tagged(cb, "compute-units", "vm/vm-vault")[0]
    assert vault_vm["hardware_id"] == router["id"] and vault_vm["kind"] == "vm" and vault_vm["cpu_cores"] == 2
    vault = tagged(cb, "services", "svc/vm-vault/vault")[0]
    assert vault["compute_id"] == vault_vm["id"] and vault["url"] == "https://vault.lan.example/"
    ssh = tagged(cb, "services", "svc/router/ssh")[0]
    assert ssh["hardware_id"] == router["id"] and ssh["ports"][0]["port"] == 22


def test_memberships_dependencies_connections_and_monitors(cb, run, inv):
    run(inv)
    lan = tagged(cb, "networks", "net/lan")[0]
    hw = {m["hardware_id"] for m in cb.hw_members[lan["id"]]}
    assert {tagged(cb, "hardware", "host/router")[0]["id"], tagged(cb, "hardware", "host/webb")[0]["id"]} == hw
    assert len(cb.cu_members[lan["id"]]) == 1
    traefik = tagged(cb, "services", "svc/router/traefik")[0]
    vault = tagged(cb, "services", "svc/vm-vault/vault")[0]
    assert cb.deps[traefik["id"]][0]["depends_on_id"] == vault["id"]
    assert len(cb.connections) == 1
    names = {m["name"] for m in cb.data["monitors"]}
    assert "router reachability [nix:mon/host/router/icmp]" in names
    http = [m for m in cb.data["monitors"] if m["check_type"] == "http"][0]
    assert http["target_type"] == "service" and http["target_id"] == vault["id"] and http["enabled"] is True
    icmp = [m for m in cb.data["monitors"] if m["name"].startswith("router reach")][0]
    assert icmp["target_type"] == "hardware"
    vm_mon = [m for m in cb.data["monitors"] if m["name"].startswith("vm-vault reach")][0]
    assert vm_mon["target_type"] == "compute_unit"


def test_declared_state_is_never_written_as_runtime_state(cb, run, inv):
    run(inv)
    for e in cb.data["services"]:
        assert "status" not in e or e["status"] is None  # never claim "running"
    for m in cb.data["monitors"]:
        assert m["status"] == "unknown"


def test_unplaced_vm_and_its_children_are_skipped_not_failed(cb, run, inv):
    report = run(inv)
    skipped = {o.key for o in actions(report, "skip")}
    assert "vm/vm-orphan" in skipped and "svc/vm-orphan/ssh" in skipped
    assert not report.errors


# ------------------------------------------------------------- idempotency
def test_second_run_performs_zero_writes(cb, run, inv):
    run(inv)
    before = len(cb.writes)
    report = run(inv)
    assert len(cb.writes) == before
    assert report.changes == []
    assert not report.errors


def test_dry_run_never_writes_and_reports_creates(cb, run, inv):
    report = run(inv, apply=False)
    assert cb.writes == []
    assert len(actions(report, "create")) >= 10
    assert all(o.action != "error" for o in report.ops)


def test_dry_run_after_apply_reports_nothing(cb, run, inv):
    run(inv)
    report = run(inv, apply=False)
    assert report.changes == []


# ---------------------------------------------------------------- changes
def test_new_host_and_vm_only_create_the_new_things(cb, run, inv):
    run(inv)
    inv2 = clone(inv)
    from inv_fixtures import res

    inv2["resources"] += [
        res("host/ermy", "host", primaryAddress="192.168.50.161", addressSource="static", hostName="ermy"),
        res("vm/vm-new", "vm", parent="host/ermy", primaryAddress="192.168.50.99", addressSource="static", vcpu=1, memoryMb=512, hostName="vm-new", placement="placed"),
    ]
    report = run(inv2)
    created = {(o.kind, o.key) for o in actions(report, "create")}
    assert created == {("hardware", "host/ermy"), ("compute", "vm/vm-new")}
    assert actions(report, "update") == []


def test_ip_change_patches_only_the_ip_and_keeps_id(cb, run, inv):
    run(inv)
    webb_id = tagged(cb, "hardware", "host/webb")[0]["id"]
    inv2 = clone(inv)
    for r in inv2["resources"]:
        if r["id"] == "host/webb":
            r["attributes"]["primaryAddress"] = "192.168.50.195"
    for rel in inv2["relationships"]:
        if rel["from"] == "host/webb":
            rel["attributes"]["address"] = "192.168.50.195"
            rel["id"] = rel["id"].replace("192.168.50.194", "192.168.50.195")
    report = run(inv2)
    ups = actions(report, "update")
    assert [(o.kind, o.key, o.detail["fields"]) for o in ups] == [("hardware", "host/webb", ["ip_address"])]
    e = tagged(cb, "hardware", "host/webb")[0]
    assert e["id"] == webb_id and e["ip_address"] == "192.168.50.195"
    lan = tagged(cb, "networks", "net/lan")[0]
    assert {m["ip_address"] for m in cb.hw_members[lan["id"]] if m["hardware_id"] == webb_id} == {"192.168.50.195"}
    assert len(cb.data["hardware"]) == 3


def test_vm_moves_to_another_host_updates_hardware_id_only(cb, run, inv):
    run(inv)
    inv2 = clone(inv)
    for r in inv2["resources"]:
        if r["id"] == "vm/vm-vault":
            r["parent"] = "host/webb"
    report = run(inv2)
    ups = actions(report, "update")
    assert ("compute", "vm/vm-vault") in {(o.kind, o.key) for o in ups}
    cu = tagged(cb, "compute-units", "vm/vm-vault")[0]
    assert cu["hardware_id"] == tagged(cb, "hardware", "host/webb")[0]["id"]


# --------------------------------------------------------------- retirement
def test_removed_resource_is_tagged_retired_never_deleted(cb, run, inv):
    run(inv)
    inv2 = remove_resource(inv, "vm/vm-vault")
    report = run(inv2)
    retired = {(o.kind, o.key) for o in actions(report, "retire")}
    assert ("compute", "vm/vm-vault") in retired and ("service", "svc/vm-vault/vault") in retired
    assert actions(report, "delete") == []
    assert not [w for w in cb.writes if w[0] == "DELETE" and "/monitors" in w[1] or w[0] == "DELETE" and "/hardware/" in w[1]]
    vm = tagged(cb, "compute-units", "vm/vm-vault")[0]
    assert "nix:retired" in vm["tags"] and "nix:id:vm/vm-vault" in vm["tags"]
    # monitors of retired resources are paused, not removed
    mon = [m for m in cb.data["monitors"] if "vm-vault" in m["name"]]
    assert mon and all(m["enabled"] is False for m in mon)
    # second run: stable
    before = len(cb.writes)
    assert run(inv2).changes == [] and len(cb.writes) == before


def test_resource_that_returns_is_unretired_and_monitor_reenabled(cb, run, inv):
    run(inv)
    run(remove_resource(inv, "vm/vm-vault"))
    report = run(inv)
    assert ("compute", "vm/vm-vault") in {(o.kind, o.key) for o in actions(report, "unretire")}
    assert "nix:retired" not in tagged(cb, "compute-units", "vm/vm-vault")[0]["tags"]
    assert all(m["enabled"] for m in cb.data["monitors"])


def test_delete_mode_requires_flag_and_waits_for_grace_period(cb, run, inv):
    with pytest.raises(policy_mod.PolicyError):
        policy_mod.from_dict({"retire": "delete"})
    pol = {"retire": "delete", "allow_delete": True, "retire_grace_days": 10}
    t0 = dt.datetime(2026, 1, 1, tzinfo=dt.timezone.utc)
    run(inv, policy=pol, now=t0)
    inv2 = remove_resource(inv, "vm/vm-vault")
    run(inv2, policy=pol, now=t0)  # tags
    assert actions(run(inv2, policy=pol, now=t0 + dt.timedelta(days=5)), "delete") == []
    report = run(inv2, policy=pol, now=t0 + dt.timedelta(days=11))
    assert {(o.kind, o.key) for o in actions(report, "delete")} >= {("compute", "vm/vm-vault"), ("service", "svc/vm-vault/vault")}
    assert not tagged(cb, "compute-units", "vm/vm-vault")


def test_retire_ignore_policy_leaves_everything_alone(cb, run, inv):
    run(inv)
    before = len(cb.writes)
    run(remove_resource(inv, "vm/vm-vault"), policy={"retire": "ignore"})
    assert len(cb.writes) == before


# ----------------------------------------------- adoption / manual preservation
def test_existing_unmanaged_entity_with_same_name_is_adopted_not_duplicated(cb, run, inv):
    manual = cb.add("hardware", name="WEBB", ip_address="192.168.50.194", notes="my own notes", tags=["homelab", "rack-2"], location="garage")
    report = run(inv)
    assert len([e for e in cb.data["hardware"] if e["name"].lower() == "webb"]) == 1
    assert ("hardware", "host/webb") in {(o.kind, o.key) for o in actions(report, "adopt")}
    e = cb.find("hardware", id=manual["id"])[0]
    assert e["notes"] == "my own notes" and e["name"] == "WEBB" and e["location"] == "garage"
    assert {"homelab", "rack-2", "nix:managed", "nix:id:host/webb"} <= set(e["tags"])


def test_discovered_device_matched_by_ip_is_adopted(cb, run, inv):
    d = cb.add("hardware", name="host-10-8-0-1", ip_address="192.168.50.1", source="discovery", tags=["discovered"])
    run(inv)
    assert tagged(cb, "hardware", "host/router")[0]["id"] == d["id"]
    assert "discovered" in d["tags"]
    assert len(cb.data["hardware"]) == 3


def test_ambiguous_match_is_skipped_with_warning_and_no_duplicate(cb, run, inv):
    cb.add("hardware", name="router", tags=[])
    cb.add("hardware", name="x", ip_address="192.168.50.1", tags=[])
    report = run(inv)
    assert any("several unmanaged entities match" in w for w in report.warnings)
    assert not tagged(cb, "hardware", "host/router")
    assert len(cb.data["hardware"]) == 4  # 2 manual + webb + switch


def test_adoption_can_be_disabled(cb, run, inv):
    cb.add("hardware", name="webb", tags=[])
    run(inv, policy={"adopt": []})
    assert len([e for e in cb.data["hardware"] if e["name"] == "webb"]) == 2


def test_manual_edits_to_unmanaged_fields_survive(cb, run, inv):
    run(inv)
    e = tagged(cb, "hardware", "host/router")[0]
    e["name"] = "My Beautiful Router"
    e["notes"] = "hand written"
    e["tags"] = sorted(e["tags"] + ["critical"])
    e["location"] = "closet"
    run(inv)
    e2 = tagged(cb, "hardware", "host/router")[0]
    assert e2["name"] == "My Beautiful Router" and e2["notes"] == "hand written"
    assert "critical" in e2["tags"] and e2["location"] == "closet"


def test_drift_in_managed_fields_is_repaired_narrowly(cb, run, inv):
    run(inv)
    e = tagged(cb, "hardware", "host/router")[0]
    e["ip_address"] = "10.9.9.9"
    e["notes"] = "keep me"
    before = len(cb.writes)
    report = run(inv)
    assert len(cb.writes) == before + 1
    assert [o.detail["fields"] for o in actions(report, "update")] == [["ip_address"]]
    assert e["notes"] == "keep me" and e["ip_address"] == "192.168.50.1"


def test_unmanaged_entities_are_never_touched_or_retired(cb, run, inv):
    manual = cb.add("hardware", name="nas", ip_address="192.168.50.50", tags=["storage"])
    manual_net = cb.add("networks", name="guest wifi", cidr="10.99.0.0/24", tags=[])
    run(inv)
    run(remove_resource(inv, "host/webb"))
    assert cb.find("hardware", id=manual["id"])[0]["tags"] == ["storage"]
    assert cb.find("networks", id=manual_net["id"])[0]["tags"] == []
    assert not any(str(manual["id"]) in p and m != "GET" for m, p in cb.log if "/hardware/" in p and p.endswith(str(manual["id"])))


def test_canvas_layout_is_never_read_or_written(cb, run, inv):
    cb.layout["nodes"]["host/router"] = {"x": 100, "y": 200}
    run(inv)
    run(remove_resource(inv, "vm/vm-vault"))
    # Positions are the operator's: nothing may read or write the layout, replace node positions
    # (PUT /topologies/{id}/nodes), or edit/delete the maps themselves. Adding or removing an
    # entity's membership of a map (POST/DELETE /maps/{id}/entities) does not move anything.
    assert not [p for _, p in cb.log if "/graph/layout" in p or "/graph/place-node" in p]
    assert not [(m, p) for m, p in cb.writes if "/graph" in p]
    assert not [(m, p) for m, p in cb.writes if p.startswith("/api/v1/topologies")]
    assert not [(m, p) for m, p in cb.writes if p.startswith("/api/v1/maps") and "/entities" not in p]
    assert cb.layout == {"nodes": {"host/router": {"x": 100, "y": 200}}}
    assert all("x" not in n and "y" not in n for n in cb.map_nodes[1])


def test_service_slug_collision_with_foreign_service_fails_cleanly_and_retries_safely(cb, run, inv):
    cb.add("services", name="x", slug="nix-svc-router-ssh", tags=[])
    report = run(inv)
    assert any(o.key == "svc/router/ssh" for o in report.errors)
    assert report.errors and not any(o.key == "svc/router/traefik" for o in report.errors)
    assert "retirement deferred" in " ".join(report.warnings)


# ----------------------------------------------------------------- failures
def test_partial_failure_is_retried_safely_without_duplicates(cb, run, inv):
    cb.fail(r"POST /api/v1/compute-units", status=500, times=1)
    r1 = run(inv)
    assert r1.errors
    # dependents of the failed VM were skipped, others created
    r2 = run(inv)
    assert not r2.errors
    assert len(cb.data["compute-units"]) == 2
    assert len(cb.data["services"]) == 3 and len(cb.data["hardware"]) == 3
    assert run(inv).changes == []


def test_lost_create_response_is_recovered_by_tag_without_duplicate(cb, run, inv):
    cb.drop_after_apply(r"POST /api/v1/hardware$", times=1)
    report = run(inv)
    assert not report.errors
    assert len(cb.data["hardware"]) == 3
    assert len({tuple(e["tags"]) for e in cb.data["hardware"]}) == 3


def test_rate_limit_is_retried_honouring_retry_after(cb, client, run, inv):
    cb.fail(r"GET /api/v1/networks$", status=429, times=2, retry_after="3")
    report = run(inv)
    assert not report.errors
    assert 3.0 in client.sleeps  # type: ignore[attr-defined]


def test_persistent_outage_raises_transient_error(cb, client, run, inv):
    cb.fail(r"GET /api/v1/networks$", status=503, times=99)
    with pytest.raises(TransientError):
        run(inv)
    assert cb.writes == []


def test_bad_token_is_an_auth_error_before_any_write(cb, run, inv):
    cb.token = "something-else"
    with pytest.raises(AuthError):
        run(inv)
    assert cb.writes == []


# --------------------------------------------------------------- safety guards
def test_empty_inventory_is_refused(inv):
    raw = clone(inv)
    raw["resources"] = []
    raw["relationships"] = []
    raw["monitors"] = []
    with pytest.raises(SafetyGuard):
        preflight_guard(inv_mod.parse(raw), State(), policy_mod.Policy())


def test_large_shrink_is_refused_unless_forced(inv):
    st = State()
    st.data["last_success"] = {"resources": 100}
    parsed = inv_mod.parse(inv)
    with pytest.raises(SafetyGuard):
        preflight_guard(parsed, st, policy_mod.Policy())
    preflight_guard(parsed, st, policy_mod.Policy(), force=True)
    preflight_guard(parsed, st, policy_mod.Policy(max_shrink_percent=0))


# ------------------------------------------------------------- compatibility
def test_check_server_accepts_tested_version(cb, client):
    info = check_server(client, tested="0.4.6")
    assert info.version == "0.4.6" and info.warnings == []


def test_same_minor_version_drift_warns(cb, client):
    cb.openapi["info"]["version"] = "0.4.9"
    info = check_server(client, tested="0.4.6")
    assert any("differs" in w for w in info.warnings)


def test_different_minor_is_incompatible_unless_allowed(cb, client):
    cb.openapi["info"]["version"] = "0.5.0"
    with pytest.raises(Incompatible):
        check_server(client, tested="0.4.6")
    assert check_server(client, tested="0.4.6", allow_untested=True).version == "0.5.0"


def test_missing_operation_or_field_is_incompatible(cb, client):
    del cb.openapi["paths"]["/api/v1/monitors"]["post"]
    with pytest.raises(Incompatible, match="POST /api/v1/monitors"):
        check_server(client, tested="0.4.6")


def test_schema_field_removal_is_incompatible(cb, client):
    del cb.openapi["components"]["schemas"]["HardwareCreate"]["properties"]["ip_address"]
    with pytest.raises(Incompatible, match="ip_address"):
        check_server(client, tested="0.4.6")


def test_adapter_requirements_hold_against_fixture_of_real_openapi():
    import json
    from fake_cb import FIXTURE

    assert adapter.check_openapi(json.loads(FIXTURE.read_text())) == []


# ---------------------------------------------------------------- monitors
def test_monitor_config_drift_is_corrected(cb, run, inv):
    run(inv)
    m = [x for x in cb.data["monitors"] if x["check_type"] == "tcp"][0]
    m["config"] = {"port": 2222}
    report = run(inv)
    assert [o.kind for o in actions(report, "update")] == ["monitor"]
    assert m["config"] == {"port": 22}


def test_user_renamed_monitor_loses_ownership_and_is_recreated_not_hijacked(cb, run, inv):
    run(inv)
    m = [x for x in cb.data["monitors"] if x["check_type"] == "icmp"][0]
    m["name"] = "my own monitor"
    run(inv)
    assert m["name"] == "my own monitor"  # untouched


def test_monitors_can_be_disabled_by_policy(cb, run, inv):
    run(inv, policy={"sync_monitors": False})
    assert cb.data["monitors"] == []


def test_remote_probe_requires_an_approved_agent(cb, run, inv):
    pol = {"remote_probes": {"mon/vm/*": "edge-1"}}
    report = run(inv, policy=pol)
    assert any("probe agent" in w for w in report.warnings)
    assert not [m for m in cb.data["monitors"] if m["name"].startswith("vm-vault reach")]
    cb.agents.append({"id": 7, "name": "edge-1", "hostname": "edge-1", "status": "active"})
    run(inv, policy=pol)
    m = [m for m in cb.data["monitors"] if m["name"].startswith("vm-vault reach")][0]
    assert m["probe_agent_id"] == 7
    # pending agents are not used
    cb.agents[0]["status"] = "pending"
    cb.data["monitors"].remove(m)
    assert any("probe agent" in w for w in run(inv, policy=pol).warnings)


# ---------------------------------------------------------------- discovery
def test_no_discovery_profile_exists_unless_explicitly_configured(cb, run, inv):
    run(inv)
    assert cb.data["profiles"] == []


def test_discovery_profile_created_and_disabled_when_removed(cb, run, inv):
    prof = {"name": "lan", "cidr": "192.168.50.0/24", "scan_types": ["nmap"]}
    run(inv, policy={"discovery": [prof]})
    p = cb.data["profiles"][0]
    assert p["name"] == "nix: lan" and p["cidr"] == "192.168.50.0/24" and p["schedule_cron"] is None and p["enabled"]
    assert run(inv, policy={"discovery": [prof]}).changes == []
    run(inv)  # profile removed from the policy
    assert p["enabled"] is False and len(cb.data["profiles"]) == 1


@pytest.mark.parametrize(
    "cidr",
    ["10.0.0.0/8", "0.0.0.0/0", "8.8.8.0/24", "127.0.0.0/24", "169.254.0.0/24", "not-a-cidr"],
)
def test_discovery_scope_is_bounded(cidr):
    with pytest.raises(policy_mod.PolicyError):
        policy_mod.from_dict({"discovery": [{"name": "x", "cidr": cidr}]})


def test_discovery_requires_explicit_cidr_and_valid_cron():
    with pytest.raises(policy_mod.PolicyError):
        policy_mod.from_dict({"discovery": [{"name": "x"}]})
    with pytest.raises(policy_mod.PolicyError):
        policy_mod.from_dict({"discovery": [{"name": "x", "cidr": "192.168.50.0/24", "schedule_cron": "daily"}]})


# ----------------------------------------------------- relationships / pruning
def test_stale_membership_is_reported_not_removed_by_default(cb, run, inv):
    run(inv)
    inv2 = clone(inv)
    inv2["relationships"] = [r for r in inv2["relationships"] if r["from"] != "host/webb"]
    report = run(inv2)
    assert [o.action for o in report.ops if o.action == "drift"]
    lan = tagged(cb, "networks", "net/lan")[0]
    assert len(cb.hw_members[lan["id"]]) == 2
    report = run(inv2, policy={"prune_relationships": True})
    assert len(cb.hw_members[lan["id"]]) == 1


def test_hardware_connection_is_created_once_via_state(cb, run, inv):
    run(inv)
    run(inv)
    assert len(cb.connections) == 1


# --------------------------------------------------------- duplicate addresses
def test_duplicate_ip_in_flake_is_created_without_ip_reported_and_stable(cb, run, inv):
    from inv_fixtures import res

    inv["resources"].append(res("host/clash", "host", primaryAddress="192.168.50.1", addressSource="static", hostName="clash"))
    report = run(inv)
    assert not report.errors
    assert any("already used by router" in w or "already used by clash" in w for w in report.warnings)
    clash_or_router = [tagged(cb, "hardware", "host/clash")[0], tagged(cb, "hardware", "host/router")[0]]
    assert sorted(e["ip_address"] is None for e in clash_or_router) == [False, True]
    before = len(cb.writes)
    again = run(inv)
    assert len(cb.writes) == before and again.changes == []
    assert [o.action for o in again.ops if o.action == "drift"]


def test_ip_conflict_is_retried_once_the_declared_address_changes(cb, run, inv):
    from inv_fixtures import res

    inv["resources"].append(res("host/clash", "host", primaryAddress="192.168.50.1", addressSource="static", hostName="clash"))
    run(inv)
    for r in inv["resources"]:
        if r["id"] == "host/clash":
            r["attributes"]["primaryAddress"] = "192.168.50.77"
    report = run(inv)
    assert tagged(cb, "hardware", "host/clash")[0]["ip_address"] == "192.168.50.77"
    assert not report.errors


def test_container_sharing_the_host_address_does_not_claim_it(cb, run, inv):
    from inv_fixtures import res

    inv["resources"].append(res("container/router/tika", "container", parent="host/router", runtime="oci", address="192.168.50.1", ports=[{"port": 9998, "protocol": "tcp"}]))
    report = run(inv)
    assert not report.errors
    assert tagged(cb, "compute-units", "container/router/tika")[0]["ip_address"] is None


def test_lost_state_does_not_duplicate_hardware_connections(cb, run, inv):
    run(inv)
    assert len(cb.connections) == 1
    from cb_sync.state import State

    report = run(inv, st=State())  # state file lost
    assert len(cb.connections) == 1 and report.changes == []


def test_lost_state_with_known_conflict_does_not_issue_empty_patches(cb, run, inv):
    from inv_fixtures import res
    from cb_sync.state import State

    inv["resources"].append(res("host/clash", "host", primaryAddress="192.168.50.1", addressSource="static", hostName="clash"))
    import copy

    run(inv)
    snapshot = copy.deepcopy(cb.data)
    report = run(inv, st=State())  # forgot the remembered conflict: one rejected PATCH, no state change
    assert cb.data == snapshot
    assert report.changes == [] and not report.errors
    assert not [w for w in cb.writes[-3:] if w[0] == "PATCH" and w[1].endswith("/0")]


def test_removing_a_remote_probe_policy_returns_the_monitor_to_the_server_vantage(cb, run, inv):
    pol = {"remote_probes": {"mon/vm/*": "edge-1"}}
    cb.agents.append({"id": 7, "name": "edge-1", "hostname": "edge-1", "status": "active"})
    run(inv, policy=pol)
    m = [m for m in cb.data["monitors"] if m["name"].startswith("vm-vault reach")][0]
    assert m["probe_agent_id"] == 7
    assert run(inv, policy=pol).changes == []
    run(inv)
    assert m["probe_agent_id"] is None


# ------------------------------------------------------------- map membership
# Circuit Breaker draws only the members of the active map; an entity created through the API
# belongs to no map, so without this the topology map stays empty.
MAPPED = {"networks": "network", "hardware": "hardware", "compute-units": "compute", "services": "service"}


def expected_members(cb, map_id=1):
    out = set()
    for coll, etype in MAPPED.items():
        out |= {(etype, e["id"]) for e in cb.data[coll] if any(t.startswith("nix:id:") for t in e.get("tags") or [])}
    return out


def test_every_owned_entity_is_placed_on_the_default_map(cb, run, inv):
    report = run(inv)
    assert not report.errors
    placed = actions(report, "place")
    members = cb.members(1)
    assert members and members == expected_members(cb)
    assert len(placed) == len(members)
    assert {o.kind for o in placed} == {"network", "hardware", "compute", "service"}
    assert all(o.detail["map"] == "Main" for o in placed)
    # monitors are not map entities
    assert not any(t == "monitor" for t, _ in members)
    # the unplaced MicroVM was skipped, so it is not on the map either
    assert "vm-orphan" not in {e["name"] for e in cb.data["compute-units"] if ("compute", e["id"]) in members}


def test_placement_is_idempotent_and_writes_nothing_the_second_time(cb, run, inv):
    run(inv)
    cb.log.clear()
    report = run(inv)
    assert not actions(report, "place") and not actions(report, "unplace")
    assert not [w for w in cb.writes if "/maps/" in w[1]]
    assert not report.changes


def test_dry_run_reports_placements_but_writes_nothing(cb, run, inv):
    report = run(inv, apply=False)
    assert actions(report, "place") and not cb.writes
    assert cb.members(1) == set()


def test_entities_added_by_hand_are_left_alone(cb, run, inv):
    hand = cb.add("hardware", name="hand-made", tags=[])
    cb.map_nodes[1].append({"entity_type": "hardware", "entity_id": hand["id"]})
    run(inv)
    assert ("hardware", hand["id"]) in cb.members(1)
    inv2 = remove_resource(inv, "vm/vm-vault")
    run(inv2)
    assert ("hardware", hand["id"]) in cb.members(1)


def test_named_map_is_used_and_the_default_map_is_not_touched(cb, run, inv):
    cb.maps.append({"id": 2, "name": "Nix", "is_default": False, "sort_order": 1})
    cb.map_nodes[2] = []
    run(inv, policy={"map_name": "Nix"})
    assert cb.members(2) == expected_members(cb) and cb.members(1) == set()


def test_missing_named_map_is_a_warning_not_a_failure(cb, run, inv):
    report = run(inv, policy={"map_name": "Does not exist"})
    assert not report.errors
    assert any("no map 'Does not exist'" in w for w in report.warnings)
    assert cb.members(1) == set()
    assert len(cb.data["hardware"]) == 3  # everything else still synced


def test_membership_can_be_switched_off(cb, run, inv):
    cb.log.clear()
    report = run(inv, policy={"map_membership": False})
    assert not actions(report, "place")
    assert not [x for x in cb.log if "/maps" in x[1] or "/topologies" in x[1]]


def test_server_without_a_maps_api_only_warns(cb, run, inv):
    cb.maps_api = False
    report = run(inv)
    assert not report.errors
    assert any("no maps API" in w for w in report.warnings)
    assert len(cb.data["services"]) == 3


def test_retired_entities_leave_the_map_but_stay_in_circuit_breaker(cb, run, inv):
    run(inv)
    vm = tagged(cb, "compute-units", "vm/vm-vault")[0]
    assert ("compute", vm["id"]) in cb.members(1)
    report = run(remove_resource(inv, "vm/vm-vault"))
    assert ("compute", "vm/vm-vault") in {(o.kind, o.key) for o in actions(report, "unplace")}
    assert ("compute", vm["id"]) not in cb.members(1)
    assert "nix:retired" in tagged(cb, "compute-units", "vm/vm-vault")[0]["tags"]  # still in Circuit Breaker
    # everything still declared stays on the map
    assert {("compute", e["id"]) for e in cb.data["compute-units"] if "nix:retired" not in e["tags"]} <= cb.members(1)


def test_retire_ignore_keeps_membership(cb, run, inv):
    run(inv, policy={"retire": "ignore"})
    vm = tagged(cb, "compute-units", "vm/vm-vault")[0]
    report = run(remove_resource(inv, "vm/vm-vault"), policy={"retire": "ignore"})
    assert not actions(report, "unplace") and ("compute", vm["id"]) in cb.members(1)


def test_a_failed_placement_is_reported_and_does_not_stop_the_rest(cb, run, inv):
    cb.fail(r"POST /api/v1/maps/1/entities", status=500, times=1)
    report = run(inv)
    assert report.errors
    # one entity missed this run; the next clean run completes the map
    report2 = run(inv)
    assert not report2.errors and cb.members(1) == expected_members(cb)


def test_unplacing_waits_for_a_clean_run(cb, run, inv):
    run(inv)
    vm = tagged(cb, "compute-units", "vm/vm-vault")[0]
    cb.fail(r"PATCH /api/v1/(compute-units|services)/\d+", status=422, times=50)  # retiring fails -> errors
    report = run(remove_resource(inv, "vm/vm-vault"))
    assert report.errors
    assert not actions(report, "unplace") and ("compute", vm["id"]) in cb.members(1)
    cb.failures.clear()
    report = run(remove_resource(inv, "vm/vm-vault"))
    assert not report.errors and ("compute", vm["id"]) not in cb.members(1)
