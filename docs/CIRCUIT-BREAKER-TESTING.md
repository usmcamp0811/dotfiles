---
type: Test Guide
title: Circuit Breaker tests
description: Which checks exist for the Circuit Breaker integration, what each proves, how to run them, and how to extend them.
tags: [circuit-breaker, testing, checks]
generated: { by: claude-agent/sonnet-5-5, at: 2026-11-01T12:00:00Z }
---

# Circuit Breaker tests

Overview of the design: [architecture](CIRCUIT-BREAKER.md). All commands run from the
repository root.

| Check | Run | Proves | Typical time |
| --- | --- | --- | --- |
| Exporter | `nix build .#checks.x86_64-linux.circuit-breaker-inventory` | 41 fixture tests: hosts, VMs and placement, addresses (static and DHCP reservation), bridges/VLANs, TAP attachment, services, proxy edges, hints, throwing/absent options, determinism, id stability, no secrets; then the real reconciler validates the output | ~30 s |
| Reconciler | `nix build .#checks.x86_64-linux.circuit-breaker-sync` | The package's pytest suite (130 tests) runs in the build | ~10 s |
| Server package | `nix build .#circuit-breaker-server` | Wheelhouse fetched and verified against upstream's lockfile hashes, UI built from its lockfile, every pinned module imports (a missing or unpatched native library fails here) and the reported version matches the pin | ~1 min cold, seconds cached |
| Module | `nix build .#checks.x86_64-linux.circuit-breaker-module` | 68 evaluation tests: generated units, secret handling (nothing secret on a command line), loopback binding, ordering, sandboxing and capabilities, every invalid option combination, and that every unit renders | ~30 s |
| End to end | `nix build -L .#checks.x86_64-linux.circuit-breaker-vm` | A NixOS VM test with the native server (all units) and the real agent on a second VM (below) | ~3 min, needs KVM and ~6 GB RAM |

Downstream flakes add their own: Campground's `circuit-breaker` (inventory of the real
configuration) and `circuit-breaker-suite` (suite plus Traefik route).

## Reconciler tests (`packages/circuit-breaker-sync/tests`)

`fake_cb.py` is an in-memory Circuit Breaker. Its OpenAPI document is the **real** 0.4.6
document trimmed to the operations and fields the adapter uses
(`fixtures/openapi-0.4.6-subset.json`), so adapter/upstream drift is caught by
`check_openapi`. Behaviours modelled: tag replacement on `PATCH`, unique slugs, one membership
per (member, network), IP-conflict 409s, `401/404/409/422`, injectable failures
(`fail(pattern, status, times, retry_after)`, `drop_after_apply`).

Covered: initial and repeated sync (zero writes), new hosts/VMs, IP changes, VM moves,
retirement and un-retirement, delete after grace, adoption and ambiguity, preservation of
manual edits and canvas layout, narrow drift repair, partial failures and safe retry, lost
responses, rate limits with `Retry-After`, outages, bad tokens, empty and shrunken
inventories, API/version drift, remote probes, discovery bounds, relationship pruning,
lost state, git-sync behaviours (revision tracking, backoff, last-good), TLS pinning, CLI
exit codes.

```bash
cd packages/circuit-breaker-sync
nix shell nixpkgs#python3Packages.pytest -c env PYTHONPATH=src pytest tests -q
```

## Exporter tests (`lib/circuit-breaker/tests.nix`)

Fixtures are plain attrsets shaped like `nixosConfigurations.<name>`, so unsupported or
throwing structures can be injected on purpose:

```bash
nix eval --impure --json --expr \
  'let lib = (builtins.getFlake "nixpkgs").lib; t = import ./lib/circuit-breaker/tests.nix { inherit lib; }; in { inherit (t) count failures; }'
```

To add a case, add an entry to `tests` with `expr` and `expected`; `failures` must stay `[]`.

## The VM test (`checks/circuit-breaker-vm`)

Nodes: `server` (the module with the natively built package; TimescaleDB makes it need
`allowUnfree`, and it gets a self-signed certificate like an operator would supply) and `edge`
(agent). The inventory comes from the exporter fixtures plus a few loopback devices. Subtests:

1. units start in order (secrets, PostgreSQL, Redis, NATS, migrations, API), all workers come up, the application reports ready, the `timescaledb` extension is installed
2. least privilege: one unprivileged account (uid 1500) runs every process; PostgreSQL/Redis/NATS listen on loopback only; only the discovery worker holds a capability; no secret appears in any process's command line; the slice caps memory
3. secrets 0400, never regenerated, in no unit file
4. first-run bootstrap through the real API
5. manual hardware entity and a saved canvas layout created before the first sync
6. token provisioned (0400) and the deployment inventory applied
7. topology matches the inventory, ownership tags, nothing claimed as running
8. manual entity and layout untouched
9. a second sync performs no writes; `cb-sync --dry-run/--validate/--status`
10. monitors report real `up`/`down` independent of the declaration
11. retire/un-retire; layout still untouched
12. empty inventory -> exit 7, nothing retired
13-16. git-driven sync from a local repository: new revision applied by the hardened unit with a real `nix build`; unchanged revision skipped; a revision that fails to evaluate changes nothing and backs off; the next good revision recovers
17. agent pending until approved, then active with telemetry; `circuit-breaker-admin agent-key` matches upstream's install script; key mode 0600
18. agent identity survives restart without re-approval
19. a monitor assigned to the agent runs from its vantage
20. data survives a restart of the whole stack
21. snapshot created with mode 0600

Debugging a failure: the log at `nix log` contains the VM consoles. A healthy start takes
about 35 seconds, so the wait timeouts are short; a hang is a real fault. Use `--max-time` on
`curl` in scripts, and never `cmd | grep -q` (the test shell runs with `pipefail`: `grep -q`
closes the pipe early and the failure is reported as exit 141) - write to a file first.

What this test found while being written (so these stay fixed): NATS parsing an environment
variable as config syntax (a token starting with a digit is read as a number) and resolving
`include` paths relative to the config; the sync service killed by seccomp on `chown`;
`install-agent.sh` failing without a certificate in the data directory; a standalone script
needing the credential vault initialised; a missing `cb-agent` on `PATH`; an over-eager
provisioning timer. (Earlier container-based versions also found a secrets directory colliding
with a unit's `RuntimeDirectory` and a duplicate `TimeoutStopSec`.)

## Re-pinning the server or agent

Everything keys off `lib/circuit-breaker/upstream.nix` (version, commit, source hash).

1. Set the new `version`, `rev` and (with `lib.fakeHash`) `hash`; build to learn the hash.
2. Regenerate the Python lock from the new source and commit it:
   `python packages/circuit-breaker-server/gen-lock.py <source-dir> > packages/circuit-breaker-server/requirements.lock.txt`
   (it reports packages without a wheel; anything new needs a decision).
3. Fix the fixed-output hashes by building with `lib.fakeHash` and copying what Nix reports:
   `wheelhouse.nix` (`hash`), `frontend.nix` (`npmDepsHash`), and the agent's `vendorHash`.
   Check the import list in `circuit-breaker-server/default.nix` still covers the dependencies.
4. Refresh `tests/fixtures/openapi-*-subset.json` from `/api/openapi.json` of the new release
   and bump `TESTED_CB_VERSION`.
5. Run all four checks above, then the VM test.
