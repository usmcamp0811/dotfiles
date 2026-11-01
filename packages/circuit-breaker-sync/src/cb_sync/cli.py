"""``circuit-breaker-sync`` command line.

Modes (exactly one):

* ``--validate``  validate the inventory file (and, with ``--check-api``, the server)
* ``--dry-run``   show what ``--apply`` would do; never writes to Circuit Breaker
* ``--apply``     reconcile the server with the inventory
* ``--status``    show the last sync result (``--live`` also probes the server)
* ``--sync-git``  fetch the trusted Git ref, export, validate and apply when it moved

Exit codes::

    0   success (nothing to do, or changes applied)
    1   unexpected error / bad usage
    2   invalid inventory or policy
    3   authentication/authorisation failure
    4   Circuit Breaker unreachable (retries exhausted)
    5   partial failure (some operations failed; safe to re-run)
    6   incompatible server or inventory schema
    7   safety guard tripped (empty / shrunk inventory); nothing was written
    10  dry-run only, with --detailed-exitcode: changes are pending
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import shutil
import sys
from pathlib import Path
from typing import Any, Sequence

from . import TESTED_CB_VERSION, __version__
from . import inventory as inventory_mod
from . import policy as policy_mod
from .client import AuthError, Client, TlsConfig, TransientError, ApiError
from .inventory import InventoryError
from .reconcile import (
    Incompatible,
    Reconciler,
    Report,
    SafetyGuard,
    check_server,
    preflight_guard,
)
from .state import State, StateError, share_with_directory_group

EXIT_OK, EXIT_FAILED, EXIT_INVALID, EXIT_AUTH, EXIT_UNREACHABLE = 0, 1, 2, 3, 4
EXIT_PARTIAL, EXIT_INCOMPATIBLE, EXIT_GUARD, EXIT_PENDING = 5, 6, 7, 10

LAST_GOOD = "last-good-inventory.json"


def _env(name: str, default: str | None = None) -> str | None:
    return os.environ.get(name, default)


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog="circuit-breaker-sync",
        description="Reconcile a Nix-flake-derived inventory into Circuit Breaker.",
    )
    mode = p.add_mutually_exclusive_group(required=True)
    mode.add_argument("--validate", action="store_true", help="validate the inventory and exit")
    mode.add_argument("--dry-run", action="store_true", help="report proposed operations without writing")
    mode.add_argument("--apply", action="store_true", help="apply the proposed operations")
    mode.add_argument("--status", action="store_true", help="show the last recorded sync result")
    mode.add_argument("--sync-git", action="store_true", help="sync from the trusted Git ref in the policy")
    p.add_argument("--inventory", default=_env("CB_SYNC_INVENTORY"), help="inventory JSON file")
    p.add_argument("--url", default=_env("CB_SYNC_URL", "https://127.0.0.1:8443"), help="Circuit Breaker base URL")
    p.add_argument("--token-file", default=_env("CB_SYNC_TOKEN_FILE"), help="file holding the API token (never pass tokens as arguments)")
    tls = p.add_mutually_exclusive_group()
    tls.add_argument("--tls-pin-file", default=_env("CB_SYNC_TLS_PIN_FILE"), help="PEM certificate to pin (server's own certificate)")
    tls.add_argument("--tls-pin", default=_env("CB_SYNC_TLS_PIN"), help="sha256 hex of the server certificate (DER) to pin")
    tls.add_argument("--ca-file", default=_env("CB_SYNC_CA_FILE"), help="CA bundle to verify the server against")
    tls.add_argument("--insecure-skip-verify", action="store_true", help="DISABLE TLS verification (not recommended)")
    p.add_argument("--state-dir", default=_env("CB_SYNC_STATE_DIR"), help="directory for state.json and the last good inventory")
    p.add_argument("--policy-file", default=_env("CB_SYNC_POLICY_FILE"), help="JSON policy file")
    p.add_argument("--revision", default=None, help="source revision to record (default: inventory.source.revision)")
    p.add_argument("--format", choices=("text", "json"), default="text")
    p.add_argument("--detailed-exitcode", action="store_true", help="with --dry-run exit 10 when changes are pending")
    p.add_argument("--check-api", action="store_true", help="with --validate/--status also verify the server API")
    p.add_argument("--live", action="store_true", help="with --status also contact the server")
    p.add_argument("--allow-untested", action="store_true", help="proceed against a Circuit Breaker version other than the tested one")
    p.add_argument("--force-shrink", action="store_true", help="bypass the inventory-shrink safety guard")
    p.add_argument("--force", action="store_true", help="with --sync-git: ignore the unchanged-revision and backoff checks")
    p.add_argument("--timeout", type=float, default=float(_env("CB_SYNC_TIMEOUT", "20")))
    p.add_argument("--retries", type=int, default=int(_env("CB_SYNC_RETRIES", "4")))
    p.add_argument("--version", action="version", version=f"%(prog)s {__version__} (tested against Circuit Breaker {TESTED_CB_VERSION})")
    return p


class Out:
    def __init__(self, fmt: str) -> None:
        self.fmt = fmt
        self.doc: dict[str, Any] = {}

    def say(self, text: str) -> None:
        if self.fmt == "text":
            print(text)

    def err(self, text: str) -> None:
        print(text, file=sys.stderr)

    def finish(self, code: int) -> int:
        self.doc["exitCode"] = code
        if self.fmt == "json":
            print(json.dumps(self.doc, indent=2, sort_keys=True))
        return code


def _client(args: argparse.Namespace, token: str | None) -> Client:
    if args.insecure_skip_verify:
        tls = TlsConfig(mode="insecure")
    elif args.tls_pin_file:
        tls = TlsConfig.pin_from_pem_file(args.tls_pin_file)
    elif args.tls_pin:
        tls = TlsConfig(mode="pin", pin_sha256=args.tls_pin)
    elif args.ca_file:
        tls = TlsConfig(mode="ca-file", ca_file=args.ca_file)
    else:
        tls = TlsConfig()
    return Client(args.url, token, tls=tls, timeout=args.timeout, retries=args.retries)


def _read_token(path: str | None) -> str | None:
    if not path:
        return None
    try:
        token = Path(path).read_text(encoding="utf-8").strip()
    except OSError as exc:
        raise AuthError(f"cannot read token file {path}: {exc}") from exc
    if not token:
        raise AuthError(f"token file {path} is empty")
    return token


def _now() -> dt.datetime:
    return dt.datetime.now(dt.timezone.utc)


def _iso(t: dt.datetime) -> str:
    return t.strftime("%Y-%m-%dT%H:%M:%SZ")


def print_report(out: Out, report: Report) -> None:
    for w in report.warnings:
        out.say(f"warning: {w}")
    verb = "applied" if report.applied else "planned"
    for o in report.ops:
        if o.action == "noop":
            continue
        extra = ""
        if o.error:
            extra = f"  ERROR: {o.error}"
        elif o.detail.get("reason"):
            extra = f"  ({o.detail['reason']})"
        elif o.detail.get("fields"):
            extra = "  [" + ", ".join(o.detail["fields"]) + "]"
        out.say(f"{o.action:<8} {o.kind:<10} {o.key}{extra}")
    counts = report.counts()
    summary = ", ".join(f"{v} {k}" for k, v in counts.items()) or "nothing to do"
    out.say(f"-- {verb}: {summary}; {report.api_calls} API calls")


def cmd_validate(args: argparse.Namespace, out: Out) -> int:
    inv = inventory_mod.load(args.inventory)
    out.doc["inventory"] = {
        "digest": inv.digest,
        "resources": len(inv.resources),
        "relationships": len(inv.relationships),
        "monitors": len(inv.monitors),
        "revision": inv.revision,
        "diagnostics": inv.diagnostics,
    }
    out.say(
        f"inventory OK: {len(inv.resources)} resources, {len(inv.relationships)} relationships, "
        f"{len(inv.monitors)} monitors (digest {inv.digest[:12]})"
    )
    for d in inv.diagnostics:
        out.say(f"{d.get('level', 'info'):<7} {d.get('code')}: {d.get('message')}")
    if args.check_api:
        client = _client(args, _read_token(args.token_file))
        info = check_server(client, tested=TESTED_CB_VERSION, allow_untested=args.allow_untested)
        out.doc["server"] = {"version": info.version, "warnings": info.warnings}
        out.say(f"server API OK (Circuit Breaker {info.version})")
        for w in info.warnings:
            out.say(f"warning: {w}")
    return EXIT_OK


def cmd_reconcile(args: argparse.Namespace, out: Out, *, apply: bool) -> int:
    try:
        state = State.load(args.state_dir)
    except StateError as exc:
        out.err(f"error: {exc}")
        return EXIT_FAILED
    attempt: dict[str, Any] = {"at": _iso(_now()), "mode": "apply" if apply else "dry-run"}
    code = EXIT_OK
    try:
        pol = policy_mod.load(args.policy_file)
        inv = inventory_mod.load(args.inventory)
        attempt.update(revision=args.revision or inv.revision, digest=inv.digest)
        if apply:
            preflight_guard(inv, state, pol, force=args.force_shrink)
        token = _read_token(args.token_file)
        client = _client(args, token)
        info = check_server(client, tested=TESTED_CB_VERSION, allow_untested=args.allow_untested)
        rec = Reconciler(client, inv, pol, state, apply=apply)
        report = rec.run()
        report.server_version = info.version
        report.api_calls = client.requests
        report.warnings = info.warnings + report.warnings
        out.doc["report"] = report.to_dict()
        print_report(out, report)
        if report.errors:
            code = EXIT_PARTIAL
        elif not apply and args.detailed_exitcode and report.changes:
            code = EXIT_PENDING
        if apply:
            attempt["result"] = "partial" if report.errors else "ok"
            attempt["counts"] = report.counts()
            if not report.errors:
                state.data["last_success"] = {
                    "at": attempt["at"],
                    "revision": attempt.get("revision"),
                    "digest": inv.digest,
                    "resources": len(inv.resources),
                    "counts": report.counts(),
                    "serverVersion": info.version,
                }
                _save_last_good(args.state_dir, args.inventory)
    except InventoryError as exc:
        attempt["result"] = "invalid-inventory"
        out.err(f"error: {exc}")
        out.doc["error"] = str(exc)
        code = EXIT_INCOMPATIBLE if exc.incompatible else EXIT_INVALID
    except policy_mod.PolicyError as exc:
        out.err(f"error: invalid policy: {exc}")
        out.doc["error"] = str(exc)
        return EXIT_INVALID
    except SafetyGuard as exc:
        attempt["result"] = "guard"
        out.err(f"error: {exc}")
        out.doc["error"] = str(exc)
        code = EXIT_GUARD
    except Incompatible as exc:
        attempt["result"] = "incompatible"
        out.err(f"error: {exc}")
        out.doc["error"] = str(exc)
        code = EXIT_INCOMPATIBLE
    except AuthError as exc:
        attempt["result"] = "auth-failed"
        out.err(f"error: authentication failed: {exc}")
        out.doc["error"] = str(exc)
        code = EXIT_AUTH
    except TransientError as exc:
        attempt["result"] = "unreachable"
        out.err(f"error: Circuit Breaker unavailable: {exc}")
        out.doc["error"] = str(exc)
        code = EXIT_UNREACHABLE
    except ApiError as exc:
        attempt["result"] = "api-error"
        out.err(f"error: {exc}")
        out.doc["error"] = str(exc)
        code = EXIT_FAILED
    if apply:
        attempt["exit"] = code
        state.data["last_attempt"] = attempt
        try:
            state.save(args.state_dir)
        except OSError as exc:
            out.err(f"warning: could not save state: {exc}")
    return code


def _save_last_good(state_dir: str | None, inventory_path: str | None) -> None:
    if not state_dir or not inventory_path:
        return
    d = Path(state_dir)
    d.mkdir(parents=True, exist_ok=True)
    tmp = d / f".{LAST_GOOD}.tmp"
    shutil.copyfile(inventory_path, tmp)
    share_with_directory_group(tmp, d)
    os.replace(tmp, d / LAST_GOOD)


def cmd_status(args: argparse.Namespace, out: Out) -> int:
    try:
        state = State.load(args.state_dir)
    except StateError as exc:
        out.err(f"error: {exc}")
        return EXIT_FAILED
    last_ok, last = state.last_success, state.data.get("last_attempt")
    out.doc["lastSuccess"] = last_ok
    out.doc["lastAttempt"] = last
    out.doc["retired"] = len(state.retired_since)
    out.say("Declared state (flake) vs observed state (Circuit Breaker monitors/agents) are separate;")
    out.say("this command only reports what the last reconciliation wrote.")
    if last_ok:
        out.say(f"last successful sync: {last_ok['at']}  revision={last_ok.get('revision')}  resources={last_ok.get('resources')}")
    else:
        out.say("no successful sync recorded")
    if last and last.get("result") != "ok":
        out.say(f"last attempt FAILED: {last.get('result')} (exit {last.get('exit')}) at {last.get('at')}")
    if state.retired_since:
        out.say(f"{len(state.retired_since)} retired (no longer declared) resource(s) are still present in Circuit Breaker")
    code = EXIT_OK
    if args.live:
        try:
            client = _client(args, _read_token(args.token_file))
            info = check_server(client, tested=TESTED_CB_VERSION, allow_untested=args.allow_untested)
            out.doc["server"] = {"version": info.version, "reachable": True, "warnings": info.warnings}
            out.say(f"server reachable, API compatible (Circuit Breaker {info.version})")
            if args.inventory:
                quiet = _Silent()
                rc = cmd_reconcile(args, quiet, apply=False)
                pending = (quiet.doc.get("report") or {}).get("changes", 0)
                out.doc["drift"] = {"pendingChanges": pending, "exit": rc}
                out.say(f"drift: {pending} pending change(s)" if rc == EXIT_OK else f"drift check failed (exit {rc})")
        except AuthError as exc:
            out.err(f"error: authentication failed: {exc}")
            code = EXIT_AUTH
        except TransientError as exc:
            out.err(f"error: server unreachable: {exc}")
            out.doc["server"] = {"reachable": False}
            code = EXIT_UNREACHABLE
        except Incompatible as exc:
            out.err(f"error: {exc}")
            code = EXIT_INCOMPATIBLE
    elif last and last.get("exit", 0) != 0:
        code = EXIT_PARTIAL
    return code


class _Silent(Out):
    def __init__(self) -> None:
        super().__init__("json")

    def say(self, text: str) -> None:  # noqa: D401
        return None

    def finish(self, code: int) -> int:
        return code


def main(argv: Sequence[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    out = Out(args.format)
    try:
        if args.validate:
            if not args.inventory:
                out.err("error: --inventory is required")
                return EXIT_FAILED
            try:
                return out.finish(cmd_validate(args, out))
            except InventoryError as exc:
                out.err(f"error: {exc}")
                out.doc["error"] = str(exc)
                return out.finish(EXIT_INCOMPATIBLE if exc.incompatible else EXIT_INVALID)
            except Incompatible as exc:
                out.err(f"error: {exc}")
                return out.finish(EXIT_INCOMPATIBLE)
            except AuthError as exc:
                out.err(f"error: authentication failed: {exc}")
                return out.finish(EXIT_AUTH)
            except TransientError as exc:
                out.err(f"error: server unreachable: {exc}")
                return out.finish(EXIT_UNREACHABLE)
        if args.status:
            return out.finish(cmd_status(args, out))
        if args.sync_git:
            from .gitsync import cmd_sync_git

            return out.finish(cmd_sync_git(args, out))
        if not args.inventory:
            out.err("error: --inventory is required")
            return EXIT_FAILED
        return out.finish(cmd_reconcile(args, out, apply=args.apply))
    except KeyboardInterrupt:
        return 130


if __name__ == "__main__":  # pragma: no cover
    sys.exit(main())
