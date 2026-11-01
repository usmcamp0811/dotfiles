---
type: NixOS Module
title: fmf.services.circuit-breaker
description: Runs the Circuit Breaker homelab topology server (natively, no container) and agent, and keeps its map in sync with the NixOS flake that declares the infrastructure.
resource: ./default.nix
tags: [services, circuit-breaker, topology, monitoring]
generated: { by: claude-agent/sonnet-5-5, at: 2026-11-01T12:00:00Z }
---

# fmf.services.circuit-breaker

[Circuit Breaker](https://github.com/BlkLeg/CircuitBreaker) (CB) is a self-hosted
topology map and monitor for homelabs. This module deploys it declaratively and makes
the flake the **source of truth for what is declared**, so nobody keeps a second
inventory by hand:

```
nixosConfigurations ──► exporter ──► inventory.json (schema v1) ──► circuit-breaker-sync ──► Circuit Breaker
 (evaluated, not grepped)   lib.fmf.circuitBreaker      versioned, no secrets        idempotent reconciler        topology + monitors
```

Read [the architecture](../../../../docs/CIRCUIT-BREAKER.md) for the design, the
[runbook](../../../../docs/CIRCUIT-BREAKER-RUNBOOK.md) for day-2 operations, and the
[troubleshooting guide](../../../../docs/CIRCUIT-BREAKER-TROUBLESHOOTING.md) when something is red.

## Quick start

```nix
fmf.services.circuit-breaker = {
  enable = true;

  server = {
    enable = true;
    domain = "topology.lan.example.com";
    # default: 127.0.0.1, plain HTTP behind a reverse proxy on this host that terminates TLS.
    # For direct access set listenAddress to a LAN address and tls.certFile/keyFile.
    secrets.generate = true;         # or secrets.vault.enable / secrets.environmentFile
    backup.enable = true;
  };

  flakeSync = {
    enable = true;
    inventory.nixosConfigurations = inputs.self.nixosConfigurations;   # deployment-driven
    inventory.flake = { name = "my-flake"; rev = inputs.self.rev or null; };
    # git = { enable = true; url = "https://git.example.com/me/config.git"; };  # git-driven
  };

  monitoring.enable = true;
};
```

On the first boot the application has no administrator. Finish first-run setup in the web
UI (`circuit-breaker-admin setup-token` prints the one-time token); within a minute the
module mints a scoped API token for the reconciler and the first sync runs.

Agents on other hosts:

```nix
fmf.services.circuit-breaker.agent = {
  enable = true;
  serverUrl = "https://topology.lan.example.com";
  serverStaticPk = "<64 hex characters>";   # or serverStaticPkFile
  tlsPin = "<base64 sha256 spki>";          # only for a self-signed server; or tlsPinFile
};
```

Hints (optional metadata the evaluated configuration cannot know) are available on
**every** host:

```nix
fmf.services.circuit-breaker.hints = {
  location = "rack 1";
  connections = [{ to = "core-switch"; type = "ethernet"; bandwidthMbps = 10000; }];
  devices.core-switch = { displayName = "Core switch"; role = "switch"; address = "10.0.0.2"; };
};
```

## What it creates

| Unit | Purpose |
| --- | --- |
| `circuit-breaker-env.service` | Stages the secrets at `/run/circuit-breaker-secrets/server.env` (0400) and derives the database and Redis URLs. Generates the secrets once, takes an external file, or is rendered by vault-agent. |
| `circuit-breaker-postgres.service` | PostgreSQL 15 + TimescaleDB, loopback only, its own port, SCRAM. Initialised on first start. |
| `circuit-breaker-redis.service`, `circuit-breaker-nats.service` | Redis (cache, pub/sub, rate limits) and NATS with JetStream (internal bus), loopback only. |
| `circuit-breaker-migrate.service` | Creates the database and runs the migrations before the API and workers start (re-runs when the package changes). |
| `circuit-breaker-api.service` | uvicorn: the API, WebSockets and the web UI. The only service that can listen beyond loopback. |
| `circuit-breaker-worker-*.service` | Discovery, notification, telemetry, integration, monitor scheduler, two monitor pollers, probe dispatch. The discovery worker alone holds `CAP_NET_RAW`. |
| `circuit-breaker.slice`, `circuit-breaker.target` | One resource cap (memory, CPU) and one switch for the whole stack. |
| `circuit-breaker-ready.service` | Succeeds once `/api/v1/readyz` reports ready. Everything that talks to the API orders after it. |
| `circuit-breaker-provision.{service,timer}` | Every minute until an administrator exists: then mints the `nix-flake-sync` token to `flakeSync.tokenFile`. |
| `circuit-breaker-sync.service` | Deployment-driven sync of the inventory built from the exact configuration being deployed. Restarts whenever the inventory changes. |
| `circuit-breaker-sync-git.{service,timer}` | Optional git-driven sync of one trusted ref. |
| `circuit-breaker-snapshot.{service,timer}` | Optional daily full-state snapshot (contains the vault key: treat as a secret). |
| `cb-agent.service` | The agent (outbound only). |

Operator commands installed on the host: `circuit-breaker-admin` (status, setup-token,
mint-sync-token, snapshot, cli …) and `cb-sync` (the reconciler with the service's exact
URL, credentials, policy and state; run with `sudo`).

## Options

### Common

| Option | Default | Notes |
| --- | --- | --- |
| `enable` | `false` | Master switch for server and/or agent on this host. |
| `hints.*` | `{}` | See above. `ignore`, `displayName`, `role`, `location`, `rack`, `tags`, `monitoring.enable`, `connections`, `services.<name>.{ignore,displayName,kind,url}`, `extraServices`, `networks`, `devices`. |
| `monitoring.enable` | `true` | Derive monitors from the inventory. |
| `monitoring.intervalSecs` | `60` | |
| `monitoring.icmp` / `ssh` / `http` | `true` | Host reachability, SSH TCP check where SSH is open, HTTPS checks for services published through a reverse proxy. |
| `monitoring.httpVerifyTls` | `true` | |
| `monitoring.tcpKinds` | reverse-proxy, database, cache, dns, auth, secrets, scm, orchestrator | Service kinds that get a TCP check on their first port. |
| `monitoring.dnsQueryName` | `null` | Set to a name that must resolve to give DNS-kind services a DNS check. |
| `monitoring.exclude` | `[]` | Inventory ids/globs never monitored. |
| `monitoring.remoteProbes` | `{}` | `"mon/host/kube-*" = "agent-hostname"`: run those monitors from an enrolled, approved agent. Never silently falls back to the server. |
| `monitoring.discovery.enable` | `false` | Explicit authorisation for active scanning. |
| `monitoring.discovery.profiles.<n>` | `{}` | `cidr` (private, no wider than /16), `scanTypes`, `schedule` (cron, or null = manual), `nmapArguments`, `enable`. |
| `monitoring.discovery.allowPublicRanges` | `false` | |

### `server.*`

| Option | Default | Notes |
| --- | --- | --- |
| `enable` | `false` | |
| `package` | `pkgs.fmf.circuit-breaker-server` | The natively built server: upstream's release, Python dependencies pinned by hash from its `poetry.lock`, web UI built from its `package-lock.json`. |
| `dataDir` | `/var/lib/circuit-breaker` | `data/` (database, bus, uploads, vault-key file) is owned by the service account; `secrets/` is root-only. |
| `user`, `uid` | `circuit-breaker`, `1500` | The one account everything runs as. The numeric id is pinned so a shared or persistent data volume stays readable. |
| `listenAddress` | `127.0.0.1` | Address the API/UI listens on. Never `0.0.0.0`. |
| `port` | `8000` | API/UI port. Plain HTTP unless `tls.*` is set. |
| `apiWorkers` | `2` | uvicorn processes of the API (each holds a copy of the application in memory). |
| `allowPlainHttp` | `false` | Needed to serve plain HTTP on a non-loopback address. |
| `internalPorts.{postgres,redis,nats}` | `15432` / `16379` / `14222` | Loopback ports of the bundled services; chosen so they cannot collide with a database you already run. |
| `postgres.{sharedBuffers,extraConfig}` | `128MB` | |
| `domain` | `null` | Public name; used by reverse-proxy integration and docs. |
| `openFirewall` | `false` | |
| `trustedProxyCidrs` | loopback | Add your reverse proxy, or every client shares one rate-limit bucket. |
| `updateCheck` | `false` | The app's daily GitHub release check. |
| `tls.certFile` / `keyFile` | `null` | Runtime paths (never store paths). Both or neither. When set the API itself serves HTTPS (the key is delivered as a systemd credential) and the public certificate is published at `<dataDir>/data/tls/fullchain.pem`, where upstream computes agent pins from. |
| `egress.allowDirect` / `proxyUrl` / `airgap` | `true` / `null` / `false` | Upstream refuses to start with neither a proxy nor direct egress. |
| `resources.memoryMax` / `cpuQuota` | `2G` / `150%` | Cap for the whole stack (`circuit-breaker.slice`). Measured: about 1.2 GiB and about 1 % of a core at steady state. |
| `secrets.generate` | `false` | Create `secrets/server.env` once. Never overwritten. |
| `secrets.environmentFile` | `null` | Your own file defining the four variables. |
| `secrets.vault.{enable,path,kvVersion,address,roleId,secretId}` | off | Render from Vault via `fmf.services.vault-agent`. Exactly one of the three secret sources. |
| `backup.enable` / `keep` | `false` / `7` | |

### `flakeSync.*`

| Option | Default | Notes |
| --- | --- | --- |
| `enable` | `false` | Requires `server.enable` on the same host. |
| `package` | `pkgs.fmf.circuit-breaker-sync` | |
| `tokenFile` | `/var/lib/circuit-breaker-sync/sync-token` | Root-only; delivered to the units with `LoadCredential`. |
| `allowUntestedVersion` | `false` | Proceed against another CB minor version. |
| `inventory.nixosConfigurations` | `null` | Normally `inputs.self.nixosConfigurations`. |
| `inventory.source` | `null` | A prebuilt inventory file instead. |
| `inventory.flake` / `exporter` | `{}` | Source metadata; exporter options (`excludeSystems`, `ignoreServices`, `extraCatalog`, `includeUnmatchedReservations`). |
| `inventory.file`, `policyFile` | read-only | The inventory and policy actually used. |
| `git.enable`, `url`, `ref`, `attr`, `credentialFile`, `buildTimeoutSecs`, `extraAllowedSchemes` | off, `""`, `main`, `circuit-breaker-inventory`, … | One fixed, trusted ref. `https`/`ssh` only unless extended; no embedded credentials. |
| `interval` | `5m` | Git ref check interval. |
| `reconcileInterval` | `null` | Re-apply the deployment inventory periodically to repair drift. |
| `policy.adopt` | `[name ip cidr]` | What may adopt a pre-existing unmanaged entity. |
| `policy.retire` | `tag` | `tag` (non-destructive), `ignore`, or `delete` (needs `allowDelete`, waits `retireGraceDays`). |
| `policy.pruneRelationships` | `false` | |
| `policy.maxShrinkPercent` | `50` | Refuse an inventory this much smaller than the last good one. |

### `agent.*`

`enable`, `package`, `serverUrl` (https, no path), `serverStaticPk`/`serverStaticPkFile`
(exactly one), `tlsPin`/`tlsPinFile`, `logLevel`, `spoolCapBytes`, `enrollTokenFile`,
`widenPingGroupRange`.

## Security properties (enforced by assertions and tests)

- Everything is built from pinned inputs: the upstream commit, the wheels (sha256 per file
  from upstream's `poetry.lock`), the npm dependencies (lockfile hash). No image, no
  download at run time.
- Secrets never enter the Nix store: they are generated at runtime, supplied as a runtime
  file, or rendered by Vault. Services read them from `/run/circuit-breaker-secrets/server.env`
  through systemd; none appears on a command line (Redis gets its password on stdin, NATS from a
  0700 runtime file, PostgreSQL from a password file removed after `initdb`).
- One unprivileged account runs everything, in a sandbox (`ProtectSystem=strict`,
  `NoNewPrivileges`, syscall filter, empty capability set). The only capability anywhere is
  `CAP_NET_RAW` on the discovery worker.
- The API binds one configured address (loopback by default); PostgreSQL, Redis and NATS bind
  loopback on private ports. Plain HTTP on a non-loopback address is rejected at evaluation time.
- The reconciler runs as an unprivileged account with an empty capability set and a
  system-call filter, reads its token as a systemd credential, and pins the server's
  certificate.
- Discovery is off unless authorised, needs an explicit private CIDR no wider than /16,
  and is rejected at evaluation time otherwise.

See [the architecture](../../../../docs/CIRCUIT-BREAKER.md#verification-status) for what is tested
and what is not.
