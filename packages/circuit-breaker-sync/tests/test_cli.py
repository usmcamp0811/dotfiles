from __future__ import annotations

import json
import subprocess

import pytest

from cb_sync import cli
from inv_fixtures import base_inventory, clone, remove_resource, write


@pytest.fixture
def env(tmp_path, cb):
    token = tmp_path / "token"
    token.write_text("test-token\n")
    inv = write(base_inventory(), tmp_path / "inv.json")
    state = tmp_path / "state"

    def args(*extra, inventory=inv):
        base = ["--url", cb.url, "--token-file", str(token), "--state-dir", str(state), "--retries", "1"]
        if inventory is not None:
            base += ["--inventory", str(inventory)]
        return base + list(extra)

    return type("E", (), {"args": staticmethod(args), "tmp": tmp_path, "inv": inv, "state": state, "token": token})


def test_apply_then_noop_and_state_written(cb, env, capsys):
    assert cli.main(env.args("--apply")) == 0
    out = capsys.readouterr().out
    assert "create" in out and "test-token" not in out
    state = json.loads((env.state / "state.json").read_text())
    assert state["last_success"]["revision"] == "a" * 40
    assert (env.state / "last-good-inventory.json").exists()
    writes = len(cb.writes)
    assert cli.main(env.args("--apply")) == 0
    assert len(cb.writes) == writes


def test_dry_run_exit_codes(cb, env):
    assert cli.main(env.args("--dry-run")) == 0
    assert cb.writes == []
    assert cli.main(env.args("--dry-run", "--detailed-exitcode")) == cli.EXIT_PENDING
    assert cli.main(env.args("--apply")) == 0
    assert cli.main(env.args("--dry-run", "--detailed-exitcode")) == 0


def test_validate_ok_and_invalid(env, capsys):
    assert cli.main(["--validate", "--inventory", str(env.inv)]) == 0
    bad = clone(base_inventory())
    bad["resources"].append(bad["resources"][0])
    p = write(bad, env.tmp / "bad.json")
    assert cli.main(["--validate", "--inventory", str(p)]) == cli.EXIT_INVALID
    old = clone(base_inventory())
    old["schemaVersion"] = 99
    p = write(old, env.tmp / "old.json")
    assert cli.main(["--validate", "--inventory", str(p)]) == cli.EXIT_INCOMPATIBLE
    assert cli.main(["--validate", "--inventory", str(env.tmp / "nope.json")]) == cli.EXIT_INVALID


def test_validate_with_check_api(cb, env):
    assert cli.main(env.args("--validate", "--check-api")) == 0
    cb.openapi["info"]["version"] = "9.9.9"
    assert cli.main(env.args("--validate", "--check-api")) == cli.EXIT_INCOMPATIBLE


def test_json_output_is_machine_readable_and_secret_free(cb, env, capsys):
    assert cli.main(env.args("--apply", "--format", "json")) == 0
    doc = json.loads(capsys.readouterr().out)
    assert doc["exitCode"] == 0 and doc["report"]["applied"] is True
    assert doc["report"]["counts"]["create"] > 5
    assert "test-token" not in json.dumps(doc)


def test_auth_failure_exit_code_and_no_writes(cb, env):
    env.token.write_text("wrong")
    assert cli.main(env.args("--apply")) == cli.EXIT_AUTH
    assert cb.writes == []
    state = json.loads((env.state / "state.json").read_text())
    assert state["last_attempt"]["result"] == "auth-failed"
    assert "last_success" not in state


def test_missing_token_file_is_an_auth_error(cb, env):
    env.token.unlink()
    assert cli.main(env.args("--apply")) == cli.EXIT_AUTH


def test_unreachable_server_exit_code(env):
    a = env.args("--apply")
    a[a.index("--url") + 1] = "http://127.0.0.1:1"
    assert cli.main(a) == cli.EXIT_UNREACHABLE


def test_partial_failure_exit_code_then_recovery(cb, env):
    cb.fail(r"POST /api/v1/services", status=500, times=1)
    assert cli.main(env.args("--apply")) == cli.EXIT_PARTIAL
    state = json.loads((env.state / "state.json").read_text())
    assert state["last_attempt"]["result"] == "partial" and "last_success" not in state
    assert cli.main(env.args("--apply")) == 0
    assert len(cb.data["services"]) == 3


def test_empty_inventory_guard_exit_code_and_nothing_written(cb, env):
    cli.main(env.args("--apply"))
    writes = len(cb.writes)
    empty = clone(base_inventory())
    empty["resources"], empty["relationships"], empty["monitors"] = [], [], []
    p = write(empty, env.tmp / "empty.json")
    assert cli.main(env.args("--apply", inventory=p)) == cli.EXIT_GUARD
    assert len(cb.writes) == writes
    # and the previous good sync record is retained
    state = json.loads((env.state / "state.json").read_text())
    assert state["last_success"]["resources"] == len(base_inventory()["resources"])
    assert state["last_attempt"]["result"] == "guard"


def test_shrink_guard_and_force(cb, env):
    cli.main(env.args("--apply"))
    shrunk = base_inventory()
    for rid in ("host/webb", "vm/vm-vault", "host/router", "device/core-switch"):
        shrunk = remove_resource(shrunk, rid)
    p = write(shrunk, env.tmp / "shrunk.json")
    assert cli.main(env.args("--apply", inventory=p)) == cli.EXIT_GUARD
    assert cli.main(env.args("--apply", "--force-shrink", inventory=p)) == 0


def test_invalid_policy_is_rejected(cb, env):
    pol = env.tmp / "pol.json"
    pol.write_text(json.dumps({"retire": "explode"}))
    assert cli.main(env.args("--apply", "--policy-file", str(pol))) == cli.EXIT_INVALID


def test_status_reports_last_result(cb, env, capsys):
    assert cli.main(env.args("--status")) == 0
    assert "no successful sync" in capsys.readouterr().out
    cli.main(env.args("--apply"))
    capsys.readouterr()
    assert cli.main(env.args("--status", "--live")) == 0
    out = capsys.readouterr().out
    assert "last successful sync" in out and "drift: 0 pending" in out and "separate" in out


def test_status_after_failure_is_nonzero(cb, env):
    env.token.write_text("bad")
    cli.main(env.args("--apply"))
    assert cli.main(env.args("--status")) == cli.EXIT_PARTIAL


def test_pin_file_requires_https_and_cert(env, tmp_path):
    a = env.args("--apply", "--tls-pin-file", str(tmp_path / "missing.pem"))
    with pytest.raises(FileNotFoundError):
        cli.main(a)


def test_entrypoint_script_runs(cb, env):
    import sys, os

    r = subprocess.run(
        [sys.executable, "-m", "cb_sync.cli", *env.args("--validate")],
        capture_output=True, text=True, env={**os.environ, "PYTHONPATH": "src"},
    )
    assert r.returncode == 0, r.stderr


def test_unreadable_state_is_an_error_not_a_silent_reset(cb, env):
    import os

    if os.geteuid() == 0:
        pytest.skip("root can read anything")
    assert cli.main(env.args("--apply")) == 0
    sp = env.state / "state.json"
    sp.chmod(0o000)
    try:
        assert cli.main(env.args("--apply")) == cli.EXIT_FAILED
        assert cli.main(env.args("--status")) == cli.EXIT_FAILED
    finally:
        sp.chmod(0o640)
    assert not (env.state / "state.corrupt").exists()  # evidence of a reset would be here


def test_state_files_are_group_shared(cb, env):
    import stat

    assert cli.main(env.args("--apply")) == 0
    for name in ("state.json", "last-good-inventory.json"):
        mode = stat.S_IMODE((env.state / name).stat().st_mode)
        assert mode == 0o660, (name, oct(mode))


def test_unprivileged_runs_never_call_chown(cb, env, monkeypatch):
    """The sync unit's seccomp filter (~@privileged) kills the process on chown(2)."""
    import os

    calls = []
    monkeypatch.setattr(os, "chown", lambda *a, **k: calls.append(a))
    monkeypatch.setattr(os, "geteuid", lambda: 1000)
    assert cli.main(env.args("--apply")) == 0
    assert calls == []
