from __future__ import annotations

import datetime as dt
from typing import Any, Callable

import pytest

from cb_sync import inventory as inv_mod
from cb_sync import policy as policy_mod
from cb_sync.client import Client
from cb_sync.reconcile import Reconciler, Report
from cb_sync.state import State
from fake_cb import FakeCB
from inv_fixtures import base_inventory


@pytest.fixture
def cb():
    with FakeCB() as server:
        yield server


@pytest.fixture
def client(cb):
    sleeps: list[float] = []
    c = Client(cb.url, cb.token, retries=3, backoff=0.01, timeout=5, sleep=sleeps.append)
    c.sleeps = sleeps  # type: ignore[attr-defined]
    return c


@pytest.fixture
def inv():
    return base_inventory()


@pytest.fixture
def run(client) -> Callable[..., Report]:
    state = State()

    def _run(raw: dict[str, Any], *, apply: bool = True, policy: dict[str, Any] | None = None, st: State | None = None, now: dt.datetime | None = None) -> Report:
        pol = policy_mod.from_dict(policy)
        clock = (lambda: now) if now else (lambda: dt.datetime.now(dt.timezone.utc))
        rec = Reconciler(client, inv_mod.parse(raw), pol, st or state, apply=apply, now=clock)
        report = rec.run()
        report.api_calls = client.requests
        return report

    _run.state = state  # type: ignore[attr-defined]
    return _run
