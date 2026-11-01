---
type: NixOS Module
title: fmf.services.circuit-breaker
description: Runs the Circuit Breaker homelab topology server and agent, and keeps its map in sync with the NixOS flake that declares the infrastructure.
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
    listenAddress = "10.0.0.30";     # the LAN address your reverse proxy / agents reach
    openFirewall = true;
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
| `circuit-breaker-env.service` | Stages the container's secrets at `/run/circuit-breaker-secrets/server.env` (0400). Generates them once, takes an external file, or is rendered by vault-agent. |
| `podman-circuit-breaker.service` (or `docker-…`) | The pinned container. Named by the oci-containers backend. |
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
| `image` | digest of upstream 0.4.6 | Must contain `@sha256:`. Ignored when `imageFile` is set. |
| `imageFile` | `null` | `dockerTools.pullImage` result; loaded instead of pulled (offline, tests). |
| `dataDir` | `/var/lib/circuit-breaker` | Root-only parent; `data/` is mounted at `/data`. |
| `listenAddress` | `127.0.0.1` | Host address the HTTPS port is published on. |
| `port` | `8443` | Host port for the UI/API (HTTPS only). |
| `httpProbePort` | `8080` | Loopback-only health probe port. |
| `domain` | `null` | Public name; used by reverse-proxy integration and docs. |
| `openFirewall` | `false` | |
| `trustedProxyCidrs` | loopback | Add your reverse proxy, or every client shares one rate-limit bucket. |
| `updateCheck` | `false` | The app's daily GitHub release check. |
| `tls.certFile` / `keyFile` | `null` | Runtime paths (never store paths). Both or neither. |
| `egress.allowDirect` / `proxyUrl` / `airgap` | `true` / `null` / `false` | Upstream refuses to start with neither a proxy nor direct egress. |
| `resources.memory` / `cpus` | `2g` / `2` | |
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

- The image is pinned by digest; floating tags are rejected.
- Secrets never enter the Nix store: they are generated at runtime, supplied as a runtime
  file, or rendered by Vault. The container only sees `/run/circuit-breaker-secrets/server.env`.
- The container is not privileged, drops all capabilities and re-adds only the eight
  upstream's compose file grants, has a read-only root, `no-new-privileges`, and mounts
  only its data directory (never a container-runtime socket).
- The UI binds one configured address; the probe port is loopback only; the database,
  cache and message bus are not published.
- The reconciler runs as an unprivileged account with an empty capability set and a
  system-call filter, reads its token as a systemd credential, and pins the server's
  certificate.
- Discovery is off unless authorised, needs an explicit private CIDR no wider than /16,
  and is rejected at evaluation time otherwise.

See [the architecture](../../../../docs/CIRCUIT-BREAKER.md#verification-status) for what is tested
and what is not.
