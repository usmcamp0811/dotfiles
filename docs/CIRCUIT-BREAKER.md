---
type: Architecture
title: Circuit Breaker topology from the flake
description: How the flake's evaluated NixOS configurations become a living, monitored Circuit Breaker topology, which side owns what, and what is and is not verified.
tags: [circuit-breaker, topology, monitoring, architecture]
generated: { by: claude-agent/sonnet-5-5, at: 2026-11-01T12:00:00Z }
---

# Circuit Breaker topology from the flake

**Goal:** the flake is the authoritative source for what is *declared*; Circuit Breaker
(CB) provides the interactive map, discovery, live monitoring and *observed* state. There
is no second inventory file to keep in step.

Related: [module reference](../modules/nixos/services/circuit-breaker/README.md),
[runbook](CIRCUIT-BREAKER-RUNBOOK.md),
[troubleshooting](CIRCUIT-BREAKER-TROUBLESHOOTING.md),
[inventory schema](CIRCUIT-BREAKER-INVENTORY.md),
[tests](CIRCUIT-BREAKER-TESTING.md).

## Components

| Piece | Where | Job |
| --- | --- | --- |
| Exporter | `lib/circuit-breaker/` (`lib.fmf.circuitBreaker`) | Pure Nix. Reads *evaluated* `nixosConfigurations` through defensive accessors and emits inventory schema v1. |
| Inventory | JSON, schema v1 | Normalised, deterministic, independent of CB's API, never contains secrets. |
| Reconciler | `packages/circuit-breaker-sync` (`circuit-breaker-sync`, `cb-sync`) | Python, standard library only. Idempotent, narrow `PATCH` updates, ownership-tagged, non-destructive by default. |
| Module | `modules/nixos/services/circuit-breaker/` | Server (pinned OCI image), sync units, optional agent, hints, assertions. |
| Agent package | `packages/circuit-breaker-agent` | Go `cb-agent` built from the pinned upstream commit, self-update disabled. |

```
                      deployment-driven                       git-driven
 nixos-rebuild/deploy ───────────────┐              trusted ref (fixed in config)
 (inventory built from the           ▼                          │ git ls-remote
  exact config being deployed)  circuit-breaker-sync.service    ▼
                                     │              circuit-breaker-sync-git.timer
                                     │                          │ nix build git+URL?rev=SHA#circuit-breaker-inventory
                                     ▼                          ▼
                              circuit-breaker-sync --apply  (validate → guard → reconcile → record revision)
                                     │
                                     ▼
                               Circuit Breaker  ◄── cb-agent (outbound only): telemetry, remote probes
```

## What is extracted

From each evaluated system (nothing is read from source files):

- **Hosts and VMs** – host name, platform, release, configuration revision, role tags
  (router, hypervisor, kubernetes), primary address and where it came from.
- **MicroVMs** – from `microvm.vms` on the parent host: placement, autostart; from the
  guest: vCPU, memory, TAP interfaces, MACs, virtiofs shares. A removed VM disappears from
  the inventory. A guest no host lists is reported as *unplaced* (info) and not synced.
- **Networks** – declared router zones and hint networks first, then CIDRs derived from
  static interface addresses. Membership is *layer-3 membership only*: a shared subnet is
  never reported as a cable.
- **Interfaces** – systemd-networkd networks and netdevs, `networking.interfaces`,
  bridges, bonds, VLANs, WireGuard (public keys and allowed IPs only), default gateway,
  nameservers.
- **Bridge attachment** – the first-matching networkd `.network` for each TAP, exactly as
  networkd applies it. When several match with different bridges the exporter warns
  (`shadowed_network_match`).
- **Services** – classified through `lib/circuit-breaker/catalog.nix` (reverse proxy,
  database, cache, DNS, auth, secrets, SCM, monitoring, storage, messaging, orchestrator,
  media, remote access) plus any `fmf.services.*` that declares a port. Low-level systemd
  units are deliberately not nodes. Firewall exposure is recorded per port.
- **Containers** – `virtualisation.oci-containers` and NixOS containers.
- **Relationships** – `member_of` (network), `attached_to` (TAP → bridge), `proxies_to`
  (Traefik routers → resolved backend service), `uses` (Vault agent clients, DNS
  resolvers), `mounts_from` (NFS and similar), `connects_to` (only from hints).
- **Monitors** – host ICMP, SSH TCP, per-service TCP and HTTPS (published hostnames),
  optional DNS. They describe *what to check*, never a result.
- **Diagnostics** – `unplaced_microvm`, `microvm_without_configuration`,
  `duplicate_microvm_placement`, `shadowed_network_match`, `duplicate_address`,
  `duplicate_id`.

What it refuses to invent: physical device metadata, cabling, rack positions, and any
address it cannot prove. Those come from `hints`.

## Ownership and identity

Identity is the inventory id (for example `vm/vm-vault`, `svc/webb/postgresql`), never an
IP address, so renumbering updates a record instead of duplicating it.

CB has no external-id field, so ownership is recorded in CB itself:

| Entity | Mark |
| --- | --- |
| Networks, hardware, compute units, services | tags `nix:managed`, `nix:id:<id>`, `nix:type:<type>`, `nix:role:*`; `nix:retired` when gone |
| Monitors | name suffix ` [nix:<id>]` |
| Discovery profiles | name prefix `nix: ` |

The reconciler only ever updates or retires entities carrying these marks. Because the
mark lives in CB, losing the reconciler's state file loses history, not ownership.

**Flake-owned fields** (repaired if they drift): hardware `ip_address`, `software_platform`,
`location` (and device role/vendor/model); compute unit kind, OS, address, vCPU, memory and
host; service ports and URL; network CIDR, VLAN, gateway; monitor definition. **Yours** (never
overwritten): names after creation, notes, tags without the `nix:` prefix, icons, canvas
layout, telemetry history.

An unmanaged entity matching by name, address or CIDR is *adopted* (tagged) instead of
duplicated; ambiguous matches are skipped with a warning. CB refuses duplicate IP
addresses, so an address declared twice in the flake is synced without the IP and reported
(`duplicate_address`).

## Three kinds of state

| State | Meaning | Where it shows |
| --- | --- | --- |
| **Committed** | What a Git ref says | The git-driven sync follows it |
| **Evaluated / desired** | What the exporter derives from a specific configuration | The inventory and CB's declared attributes |
| **Deployed / observed** | What machines run and what answers | CB monitors, agent telemetry |

The sync moves *desired* state only. A host appearing in CB means it is declared, not that it
is up: monitors start at `unknown`, and nothing the reconciler writes sets a status of
`running`. If a Git revision is ahead of what is deployed, CB shows the newer plan.

Deployment-driven and git-driven sync can both be enabled; the most recent run wins, and
the module warns. Use deployment-driven alone for "CB matches what I deployed", git-driven
alone for "CB matches `main`".

## Safety rules

- A failed or empty evaluation never changes CB: an inventory without hosts exits 7; one
  that shrank by more than `maxShrinkPercent` exits 7; invalid or secret-looking input exits 2.
- Removal only tags `nix:retired` and pauses the entity's monitors. Hard delete needs
  `policy.retire = "delete"`, `allowDelete = true` and survives `retireGraceDays`.
- Retirement is skipped in a run that had errors.
- API drift: the OpenAPI document is checked before any write (operations and fields the
  adapter uses); a different minor version is refused unless `allowUntestedVersion`.
- Timeouts, bounded retries, backoff. A write whose response was lost is recovered by looking
  the entity up by its ownership mark before retrying.
- The Git source and ref come only from the NixOS configuration; there is no command-line
  override. `flake.lock` is never modified (`--no-update-lock-file`). A revision that fails is
  retried with exponential backoff (5 min doubling to 6 h) and the last good topology stays.

## Verification status

Honest account of what has actually been exercised.

| Area | Evidence |
| --- | --- |
| Exporter | 40 pure-Nix tests (`lib/circuit-breaker/tests.nix`); run on the real Campground (196 resources, 275 relationships, 117 monitors) |
| Reconciler | 118 pytest cases against a fake of CB 0.4.6 built from its real OpenAPI document; mutation spot-checks; run repeatedly against the real pinned container |
| Module | 62 evaluation-level tests including every invalid option combination, and a test that every unit renders |
| End to end | NixOS VM test (`checks/circuit-breaker-vm`): real pinned image under podman, real agent on a second VM, hardened sync units, git-driven sync with a real `nix build` |
| Not tested | MicroVM boot of the server; Vault-rendered secrets at runtime (evaluated only); a real Gitea credential flow; `cb restore` of an upstream snapshot; ARP/L2 discovery results (needs a helper outside the container) |

## Known limitations

- CB's `/api/v1` is **not a stable public API** (upstream says so). The adapter is pinned to
  0.4.6 and checks the OpenAPI document; upgrading CB means re-running the tests.
- CB has no endpoint to list hardware connections; the reconciler finds existing ones
  through the topology graph and remembers the ids it created.
- The server serves the UI over HTTPS only; HTTP redirects. A reverse proxy to a self-signed
  container certificate must skip verification for that hop unless `server.tls.*` is set.
- Discovery by ARP needs host-side helper permissions the container does not have; use
  agents on the segment for L2 discovery.
- A server on one host cannot sync a flake whose hosts it cannot name: addresses come from
  static configuration or router DHCP reservations; DHCP-only machines without a
  reservation have no address and get no address-based monitors.
