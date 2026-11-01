"""Git-driven synchronisation.

``circuit-breaker-sync --sync-git`` implements the "trusted ref" flow:

1. resolve the configured ref of the configured repository with ``git ls-remote``
   (no clone, no arbitrary URL - both come from the policy file written by the
   NixOS module, never from the command line);
2. stop if that revision was already synchronised, or recently failed (backoff);
3. build the inventory output of that exact revision with
   ``nix build --no-update-lock-file`` (``flake.lock`` is never modified);
4. validate and apply it through the normal ``--apply`` path;
5. only on full success record the revision and keep the inventory as the last
   known good one.

Declared (committed) state is *not* deployed state: this only moves the
*desired* topology. See docs/CIRCUIT-BREAKER.md.
"""

from __future__ import annotations

import argparse
import datetime as dt
import os
import re
import subprocess
from typing import Any, Callable, Sequence

from . import policy as policy_mod
from .state import State

REV_RE = re.compile(r"^[0-9a-f]{40}$")
BACKOFF_BASE = dt.timedelta(minutes=5)
BACKOFF_MAX = dt.timedelta(hours=6)

Runner = Callable[..., subprocess.CompletedProcess]


class GitSyncError(Exception):
    pass


def _git_env(git: dict[str, Any]) -> dict[str, str]:
    env = dict(os.environ)
    env["GIT_TERMINAL_PROMPT"] = "0"
    cred = git.get("credential_file") or os.environ.get("CB_SYNC_GIT_CREDENTIAL_FILE")
    if cred:
        # git-credential-store format file, supplied as a runtime secret.
        env.update(
            GIT_CONFIG_COUNT="1",
            GIT_CONFIG_KEY_0="credential.helper",
            GIT_CONFIG_VALUE_0=f"store --file={cred}",
        )
    return env


def resolve_revision(git: dict[str, Any], run: Runner = subprocess.run) -> str:
    """Return the commit id the trusted ref currently points at."""
    ref = git["ref"]
    candidates = [f"refs/heads/{ref}", f"refs/tags/{ref}"]
    proc = run(
        ["git", "ls-remote", "--exit-code", git["url"], *candidates],
        capture_output=True,
        text=True,
        env=_git_env(git),
        timeout=120,
        check=False,
    )
    if proc.returncode != 0:
        raise GitSyncError(f"git ls-remote failed for ref {ref!r}: {proc.stderr.strip()[:300] or proc.returncode}")
    for line in proc.stdout.splitlines():
        rev = line.split()[0] if line.split() else ""
        if REV_RE.match(rev):
            return rev
    raise GitSyncError(f"ref {ref!r} did not resolve to a commit")


def build_inventory(git: dict[str, Any], rev: str, run: Runner = subprocess.run) -> str:
    """Evaluate the flake at ``rev`` and return the store path of the inventory file."""
    installable = f"git+{git['url']}?rev={rev}#{git['attr']}"
    proc = run(
        [
            "nix",
            "--extra-experimental-features",
            "nix-command flakes",
            "build",
            "--no-link",
            "--print-out-paths",
            "--no-update-lock-file",
            installable,
        ],
        capture_output=True,
        text=True,
        env=_git_env(git),
        timeout=int(git.get("build_timeout", 3600)),
        check=False,
    )
    if proc.returncode != 0:
        tail = "\n".join(proc.stderr.strip().splitlines()[-8:])
        raise GitSyncError(f"nix build failed for {rev[:12]}: {tail}")
    paths = [p for p in proc.stdout.split() if p.startswith("/")]
    if len(paths) != 1:
        raise GitSyncError(f"expected exactly one output path, got {paths!r}")
    return paths[0]


def backoff_for(count: int) -> dt.timedelta:
    return min(BACKOFF_BASE * (2 ** max(count - 1, 0)), BACKOFF_MAX)


def cmd_sync_git(
    args: argparse.Namespace,
    out: Any,
    *,
    run: Runner = subprocess.run,
    now: Callable[[], dt.datetime] = lambda: dt.datetime.now(dt.timezone.utc),
    apply_fn: Callable[[argparse.Namespace, Any], int] | None = None,
) -> int:
    from .cli import EXIT_FAILED, EXIT_INVALID, EXIT_OK, cmd_reconcile  # local import: avoid cycle

    try:
        pol = policy_mod.load(args.policy_file)
    except policy_mod.PolicyError as exc:
        out.err(f"error: invalid policy: {exc}")
        return EXIT_INVALID
    if pol.git is None:
        out.err("error: no git source configured in the policy (fmf.services.circuit-breaker.flakeSync.git)")
        return EXIT_INVALID
    state = State.load(args.state_dir)
    try:
        rev = resolve_revision(pol.git, run)
    except GitSyncError as exc:
        out.err(f"error: {exc}")
        return EXIT_FAILED
    out.doc["revision"] = rev

    last = (state.last_success or {}).get("revision")
    if last == rev and not args.force:
        out.say(f"revision {rev[:12]} already synchronised; nothing to do")
        out.doc["result"] = "unchanged"
        return EXIT_OK

    attempt = state.attempts.get(rev)
    if attempt and not args.force:
        due = dt.datetime.strptime(attempt["next_after"], "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=dt.timezone.utc)
        if now() < due:
            out.say(f"revision {rev[:12]} failed {attempt['count']}x; next retry after {attempt['next_after']}")
            out.doc["result"] = "backoff"
            return EXIT_OK  # not an error: the previous failure was already reported

    try:
        path = build_inventory(pol.git, rev, run)
        # Re-enter the normal apply path with this exact inventory.
        args2 = argparse.Namespace(**{**vars(args), "inventory": path, "revision": rev, "apply": True, "dry_run": False})
        code = (apply_fn or (lambda a, o: cmd_reconcile(a, o, apply=True)))(args2, out)
    except GitSyncError as exc:
        out.err(f"error: {exc}")
        code = EXIT_FAILED
    state = State.load(args.state_dir)  # cmd_reconcile saved its own changes
    if code == EXIT_OK:
        state.attempts.pop(rev, None)
        out.doc["result"] = "synced"
    else:
        count = (attempt or {}).get("count", 0) + 1
        nxt = now() + backoff_for(count)
        state.attempts[rev] = {"count": count, "next_after": nxt.strftime("%Y-%m-%dT%H:%M:%SZ"), "exit": code}
        out.doc["result"] = "failed"
        out.err(f"revision {rev[:12]} failed (exit {code}); the last known good inventory stays in place")
    # keep the attempts table bounded
    for old in sorted(state.attempts)[:-20]:
        state.attempts.pop(old, None)
    state.save(args.state_dir)
    return code


__all__: Sequence[str] = ["cmd_sync_git", "resolve_revision", "build_inventory", "GitSyncError"]
