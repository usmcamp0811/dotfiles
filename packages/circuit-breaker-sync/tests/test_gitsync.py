from __future__ import annotations

import argparse
import datetime as dt
import json
import subprocess

import pytest

from cb_sync import cli, gitsync
from cb_sync.state import State
from inv_fixtures import base_inventory, write

REV1, REV2 = "1" * 40, "2" * 40


class FakeRun:
    """Stand-in for subprocess.run recording argv and returning scripted results."""

    def __init__(self, tmp, rev=REV1, build_ok=True):
        self.rev, self.build_ok, self.calls, self.tmp = rev, build_ok, [], tmp
        self.inv_path = write(base_inventory(), tmp / "built.json")

    def __call__(self, argv, **kw):
        self.calls.append((argv, kw))
        if argv[0] == "git":
            return subprocess.CompletedProcess(argv, 0, f"{self.rev}\trefs/heads/main\n", "")
        if argv[0] == "nix":
            if not self.build_ok:
                return subprocess.CompletedProcess(argv, 1, "", "error: evaluation failed\nboom")
            return subprocess.CompletedProcess(argv, 0, f"{self.inv_path}\n", "")
        raise AssertionError(argv)


@pytest.fixture
def setup(tmp_path, cb):
    token = tmp_path / "t"
    token.write_text("test-token")
    pol = tmp_path / "policy.json"
    pol.write_text(json.dumps({"git": {"url": "https://git.example/campground/config.git", "ref": "main", "attr": "circuit-breaker-inventory"}}))
    state = tmp_path / "state"

    def ns(**over):
        base = dict(
            inventory=None, url=cb.url, token_file=str(token), tls_pin_file=None, tls_pin=None, ca_file=None,
            insecure_skip_verify=False, state_dir=str(state), policy_file=str(pol), revision=None, format="text",
            detailed_exitcode=False, check_api=False, live=False, allow_untested=False, force_shrink=False,
            force=False, timeout=5.0, retries=0, apply=False, dry_run=False, validate=False, status=False, sync_git=True,
        )
        base.update(over)
        return argparse.Namespace(**base)

    return ns, state, tmp_path


def test_new_revision_is_built_applied_and_recorded(cb, setup):
    ns, state, tmp = setup
    run = FakeRun(tmp)
    out = cli.Out("text")
    assert gitsync.cmd_sync_git(ns(), out, run=run) == 0
    nix = [c for c in run.calls if c[0][0] == "nix"][0][0]
    assert "--no-update-lock-file" in nix
    assert nix[-1] == f"git+https://git.example/campground/config.git?rev={REV1}#circuit-breaker-inventory"
    st = State.load(state)
    assert st.last_success["revision"] == REV1
    assert len(cb.data["hardware"]) == 3


def test_unchanged_revision_is_not_rebuilt(cb, setup):
    ns, state, tmp = setup
    run = FakeRun(tmp)
    gitsync.cmd_sync_git(ns(), cli.Out("text"), run=run)
    run2 = FakeRun(tmp)
    assert gitsync.cmd_sync_git(ns(), cli.Out("text"), run=run2) == 0
    assert [c for c in run2.calls if c[0][0] == "nix"] == []


def test_failed_build_keeps_last_good_and_backs_off(cb, setup):
    ns, state, tmp = setup
    gitsync.cmd_sync_git(ns(), cli.Out("text"), run=FakeRun(tmp, rev=REV1))
    good = (state / "last-good-inventory.json").read_text()
    t0 = dt.datetime(2026, 1, 1, tzinfo=dt.timezone.utc)
    bad = FakeRun(tmp, rev=REV2, build_ok=False)
    assert gitsync.cmd_sync_git(ns(), cli.Out("text"), run=bad, now=lambda: t0) != 0
    st = State.load(state)
    assert st.last_success["revision"] == REV1 and st.attempts[REV2]["count"] == 1
    assert (state / "last-good-inventory.json").read_text() == good
    # inside the backoff window the same broken revision is not evaluated again
    bad2 = FakeRun(tmp, rev=REV2, build_ok=False)
    assert gitsync.cmd_sync_git(ns(), cli.Out("text"), run=bad2, now=lambda: t0 + dt.timedelta(minutes=1)) == 0
    assert [c for c in bad2.calls if c[0][0] == "nix"] == []
    # after the window it retries, with a longer backoff
    bad3 = FakeRun(tmp, rev=REV2, build_ok=False)
    assert gitsync.cmd_sync_git(ns(), cli.Out("text"), run=bad3, now=lambda: t0 + dt.timedelta(minutes=10)) != 0
    assert State.load(state).attempts[REV2]["count"] == 2
    # --force bypasses the backoff
    ok = FakeRun(tmp, rev=REV2)
    assert gitsync.cmd_sync_git(ns(force=True), cli.Out("text"), run=ok) == 0
    assert State.load(state).last_success["revision"] == REV2


def test_backoff_grows_and_is_capped():
    assert gitsync.backoff_for(1) == dt.timedelta(minutes=5)
    assert gitsync.backoff_for(3) == dt.timedelta(minutes=20)
    assert gitsync.backoff_for(30) == dt.timedelta(hours=6)


def test_requires_git_policy(cb, setup):
    ns, state, tmp = setup
    pol = tmp / "nogit.json"
    pol.write_text("{}")
    assert gitsync.cmd_sync_git(ns(policy_file=str(pol)), cli.Out("text"), run=FakeRun(tmp)) == cli.EXIT_INVALID


@pytest.mark.parametrize(
    "git",
    [
        {"url": "u", "ref": "main; rm -rf /", "attr": "x"},
        {"url": "u", "ref": "main", "attr": "x y"},
        {"url": "", "ref": "main", "attr": "x"},
    ],
)
def test_policy_rejects_unsafe_git_settings(git):
    from cb_sync import policy

    with pytest.raises(policy.PolicyError):
        policy.from_dict({"git": git})


def test_ls_remote_failure_is_reported(cb, setup):
    ns, state, tmp = setup

    def boom(argv, **kw):
        return subprocess.CompletedProcess(argv, 2, "", "fatal: unable to access")

    assert gitsync.cmd_sync_git(ns(), cli.Out("text"), run=boom) == cli.EXIT_FAILED


def test_url_cannot_come_from_the_command_line():
    # The CLI has no --git-url/--flake option at all: only the policy file names the source.
    help_text = cli.build_parser().format_help()
    assert "--git-url" not in help_text and "--flake" not in help_text


def test_credentials_are_passed_through_git_config_env_only(tmp_path):
    env = gitsync._git_env({"credential_file": "/run/secrets/git-cred"})
    assert env["GIT_CONFIG_VALUE_0"] == "store --file=/run/secrets/git-cred"
    assert env["GIT_TERMINAL_PROMPT"] == "0"
