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
| Exporter | `nix build .#checks.x86_64-linux.circuit-breaker-inventory` | 40 fixture tests: hosts, VMs and placement, addresses (static and DHCP reservation), bridges/VLANs, TAP attachment, services, proxy edges, hints, throwing/absent options, determinism, id stability, no secrets; then the real reconciler validates the output | ~30 s |
| Reconciler | `nix build .#checks.x86_64-linux.circuit-breaker-sync` | The package's pytest suite (118 tests) runs in the build | ~10 s |
| Module | `nix build .#checks.x86_64-linux.circuit-breaker-module` | 62 evaluation tests: generated units and container options, secret handling, ordering, hardening, every invalid option combination, and that every unit renders | ~30 s |
| End to end | `nix build -L .#checks.x86_64-linux.circuit-breaker-vm` | A NixOS VM test with the real pinned image under podman and the real agent on a second VM (below) | ~4 min, needs KVM and ~6 GB RAM |

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

Nodes: `server` (module, image loaded from a `dockerTools.pullImage` pinned by digest and
content hash, so it needs no network) and `edge` (agent). The inventory comes from the exporter
fixtures plus a few loopback devices. Subtests:

1. image loads, container starts, reports ready and healthy
2. least privilege: not privileged, read-only root, exactly the eight upstream capabilities, only the data mount, no runtime socket, nothing on the wildcard address, probe port loopback-only
3. secrets 0400, never regenerated, in no unit file
4. first-run bootstrap through the real API
5. manual hardware entity and a saved canvas layout created before the first sync
6. token provisioned (0400) and the deployment inventory applied
7. topology matches the inventory, ownership tags, nothing claimed as running
8. manual entity and layout untouched
9. a second sync performs no writes; `cb-sync --dry-run/--validate/--status`
10. monitors report real `up`/`down` independent of the declaration
11. retire/un-retire; layout still untouched
12. empty inventory → exit 7, nothing retired
13–16. git-driven sync from a local repository: new revision applied by the hardened unit with a real `nix build`; unchanged revision skipped; a revision that fails to evaluate changes nothing and backs off; the next good revision recovers
17. agent pending until approved, then active with telemetry; key mode 0600
18. agent identity survives restart without re-approval
19. a monitor assigned to the agent runs from its vantage
20. data survives a container restart
21. snapshot created with mode 0600

Debugging a failure: the log at `nix log` contains the VM consoles. Bring-up problems show
up in subtest 1; a hung `curl` right after a restart needs `--max-time`.

What this test found while being written (so these stay fixed): a secrets directory that
collided with the container unit's `RuntimeDirectory`; podman's `tmpcopyup` overflowing the
tmpfs mounts; a duplicate `TimeoutStopSec`; the sync service killed by seccomp on `chown`;
a missing `cb-agent` on `PATH`; an over-eager provisioning timer.

## Re-pinning the image or agent

1. New digest: `skopeo inspect docker://ghcr.io/blkleg/circuitbreaker:<tag> | jq -r .Digest`.
2. New image hash for the VM test: set `sha256 = lib.fakeHash`, build, copy the reported hash.
3. Agent: update `rev` and `hash` in `packages/circuit-breaker-agent/default.nix`, then
   `vendorHash` (same trick).
4. Refresh `tests/fixtures/openapi-*-subset.json` from `/api/openapi.json` of the new release
   and bump `TESTED_CB_VERSION`.
