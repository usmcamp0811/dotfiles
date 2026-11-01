"""Persistent reconciler state (a small JSON file).

The state is a *cache and bookkeeping aid*, never the source of truth: ownership
is recorded in Circuit Breaker itself (``nix:`` tags), so losing this file loses
only history (retirement clocks, last-synced revision), not the ability to
reconcile without duplicates.
"""

from __future__ import annotations

import json
import os
import tempfile
from pathlib import Path
from typing import Any

STATE_VERSION = 1
STATE_FILE = "state.json"


def share_with_directory_group(path: str | Path, directory: str | Path) -> None:
    """Make ``path`` readable/writable by the directory's group.

    The reconciler runs both as an unprivileged service account and, when an
    operator invokes it by hand, as root. Both must be able to read and replace
    the same files, so files take the state directory's group and mode 0660.
    """
    os.chmod(path, 0o660)
    # Only root ever needs to change the group (a non-root service user already creates
    # files in its own group). Avoiding the call for everyone else matters: the
    # service's seccomp filter (~@privileged) kills the process on chown(2).
    if os.geteuid() == 0:
        os.chown(path, -1, os.stat(directory).st_gid)



class StateError(Exception):
    """The state file exists but cannot be used. Never silently reset: that would lose
    retirement clocks and remembered conflicts."""


class State:
    def __init__(self, data: dict[str, Any] | None = None) -> None:
        self.data: dict[str, Any] = data or {}
        self.data.setdefault("version", STATE_VERSION)
        for key in ("entities", "retired_since", "links", "attempts", "ip_conflicts"):
            self.data.setdefault(key, {})

    # -- persistence ---------------------------------------------------------
    @classmethod
    def load(cls, directory: str | Path | None) -> "State":
        if directory is None:
            return cls()
        path = Path(directory) / STATE_FILE
        try:
            return cls(json.loads(path.read_text(encoding="utf-8")))
        except FileNotFoundError:
            return cls()
        except PermissionError as exc:
            raise StateError(
                f"cannot read {path}: {exc} (was it written by another user? it must be readable by the sync service account)"
            ) from exc
        except (OSError, ValueError):
            # A corrupt state file must not stop reconciliation: ownership lives
            # in Circuit Breaker. Keep the evidence for debugging.
            try:
                path.rename(path.with_suffix(".corrupt"))
            except OSError:
                pass
            return cls()

    def save(self, directory: str | Path | None) -> None:
        if directory is None:
            return
        d = Path(directory)
        d.mkdir(parents=True, exist_ok=True)
        fd, tmp = tempfile.mkstemp(dir=d, prefix=".state-", suffix=".tmp")
        try:
            with os.fdopen(fd, "w", encoding="utf-8") as fh:
                json.dump(self.data, fh, indent=2, sort_keys=True)
                fh.write("\n")
                fh.flush()
                os.fsync(fh.fileno())
            share_with_directory_group(tmp, d)
            os.replace(tmp, d / STATE_FILE)
        finally:
            if os.path.exists(tmp):
                os.unlink(tmp)

    # -- accessors -------------------------------------------------------------
    @property
    def entities(self) -> dict[str, dict[str, Any]]:
        return self.data["entities"]

    @property
    def retired_since(self) -> dict[str, str]:
        return self.data["retired_since"]

    @property
    def links(self) -> dict[str, dict[str, Any]]:
        return self.data["links"]

    @property
    def ip_conflicts(self) -> dict[str, dict[str, Any]]:
        return self.data["ip_conflicts"]

    @property
    def attempts(self) -> dict[str, dict[str, Any]]:
        return self.data["attempts"]

    @property
    def last_success(self) -> dict[str, Any] | None:
        return self.data.get("last_success")

    @property
    def last_result(self) -> dict[str, Any] | None:
        return self.data.get("last_result")
