---
type: Runbook
title: Circuit Breaker runbook
description: Install, first-run setup, daily operation, agents, discovery, backup and restore, secret rotation, upgrade and rollback for the flake-driven Circuit Breaker.
tags: [circuit-breaker, runbook, operations]
generated: { by: claude-agent/sonnet-5-5, at: 2026-11-01T12:00:00Z }
---

# Circuit Breaker runbook

Design: [architecture](CIRCUIT-BREAKER.md). Options: [module reference](../modules/nixos/services/circuit-breaker/README.md).
Problems: [troubleshooting](CIRCUIT-BREAKER-TROUBLESHOOTING.md).

Commands below run on the Circuit Breaker host unless noted. `cb-sync` and
`circuit-breaker-admin` are installed by the module; `cb-sync` needs `sudo` because it reads
the root-only API token.

## 0. Choose the host

Requirements: podman (set automatically by the oci-containers backend), about 2 GB RAM for
the container plus the OS, 10 GB of persistent disk, a persistent `/var/lib/circuit-breaker`,
and outbound access to nothing (the app works air-gapped). Prefer a host that is always on
and whose network can reach the machines you want probed. Do not co-locate it with your
secrets manager.

On a MicroVM host the container store (`/var/lib/containers`, overlayfs) needs a real block
volume, not virtiofs or RAM, and `/var/lib/circuit-breaker` and `/var/lib/circuit-breaker-sync`
must be persistent shares. **This layout has not been booted in tests**; the module is
verified on a regular NixOS VM.

### Running next to your reverse proxy

If the host already runs Traefik (or another proxy), keep the server on loopback:
`server.listenAddress = "127.0.0.1"` (the default), publish it with a router to
`https://127.0.0.1:8443`, and no firewall port is needed. Two things to check:

- **Port collisions.** The container publishes `httpProbePort` (default `8080`, loopback) in
  addition to the UI port. Traefik with `api.insecure = true` listens on `:8080`, so set
  `server.httpProbePort` to something free (for example `18080`) or the container will fail to
  start with "address already in use".
- **Resources.** Measured on the pinned image: about 1.2 GiB RSS and about 1 % of a core at
  steady state, busier for the first minute (migrations). Set `server.resources.cpus` for
  small hosts. Leave `flakeSync.git` off on a small host: it evaluates the flake with `nix`.

The exporter follows loopback backends: a proxy route to `127.0.0.1:<port>` becomes a
`proxies_to` edge to the service on the same system, and the published name gets its HTTPS monitor.

## 1. Install

1. Pick a secret source (exactly one):
   - `server.secrets.generate = true;` – created once under `<dataDir>/secrets/server.env`
     (0400, root). **Back this file up with the data**: the database and the vault are keyed
     to it. It is never regenerated.
   - `server.secrets.environmentFile = "/run/…";` – your file with `CB_DB_PASSWORD`,
     `CB_VAULT_KEY` (a Fernet key), `CB_JWT_SECRET` and `NATS_AUTH_TOKEN`.
   - `server.secrets.vault.enable = true;` – store those four keys in Vault at
     `server.secrets.vault.path` (KV v2 by default) and enable `fmf.services.vault-agent`.
2. Enable the module (see the [module README](../modules/nixos/services/circuit-breaker/README.md)),
   set `server.listenAddress` to the address clients use, deploy.
3. Wait for readiness:
   ```bash
   systemctl status circuit-breaker-ready.service      # active (exited) when /readyz is ready
   circuit-breaker-admin status
   journalctl -u podman-circuit-breaker -f
   ```
   A cold first start takes about a minute; the first image load a few minutes more.

## 2. First-run administrator

Until an administrator exists the API answers only the setup endpoints.

```bash
circuit-breaker-admin setup-token    # prints the one-time token; refuses once setup is complete
```

Open `https://<listenAddress>:8443` (accept the self-signed certificate once, or provide
`server.tls.*`), create the administrator with the token, and complete the wizard. Set
**Settings → Connectivity → App URL** to the name users use and add an **Agent endpoint** with
the URL agents should dial.

Write down the *vault key* the wizard shows; it is also in `server.env`.

## 3. Service account for the reconciler

Automatic. `circuit-breaker-provision.timer` checks `bootstrap/status` every minute (a cheap
HTTP call); as soon as an administrator exists it runs `circuit-breaker-admin mint-sync-token`,
which creates a token labelled `nix-flake-sync` with scopes `read:*` and `write:*` (no admin,
no delete) and writes it 0400 to `flakeSync.tokenFile`. Then it starts the sync.

Manual or rotation:

```bash
sudo circuit-breaker-admin mint-sync-token   # creates, or rotates the existing token (old secret dies immediately)
sudo rm /var/lib/circuit-breaker-sync/sync-token && sudo systemctl start circuit-breaker-provision   # re-provision from scratch
circuit-breaker-admin cli token list          # id, label, scopes, expiry, last use (never the secret)
circuit-breaker-admin cli token revoke <id>
```

Set `flakeSync.token.expiresInDays` if you prefer expiring tokens.

## 4. Look at what the flake produces

```bash
# in the downstream flake (Campground exports this package):
nix build .#circuit-breaker-inventory && jq '{resources: (.resources|length), warnings: .diagnostics}' result

# the inventory a given host will actually sync (works wherever the module is enabled):
nix eval --raw .#nixosConfigurations.<host>.config.fmf.services.circuit-breaker.flakeSync.inventory.file

# on the host itself: schema + secret scan of the deployed inventory
sudo cb-sync --validate
```

Warnings in `.diagnostics` are findings about the flake itself. Treat them as bugs to look
at: `shadowed_network_match` (a TAP will not end up on the bridge you wrote),
`duplicate_address` (two machines claim one IP), `microvm_without_configuration`,
`unplaced_microvm`.

## 5. Synchronising

### Deployment-driven (default)

Every deploy builds an inventory from the exact configurations being deployed. Its store
path is part of `circuit-breaker-sync.service`, so a changed inventory restarts the unit and
the sync runs by itself. Nothing reads a mutable Git checkout.

```bash
sudo cb-sync --dry-run                 # what would change; never writes
sudo cb-sync --dry-run --detailed-exitcode   # exit 10 if changes are pending
sudo cb-sync --apply
sudo cb-sync --validate [--check-api]
sudo cb-sync --status [--live]         # last recorded result; --live also contacts the server and shows drift
sudo cb-sync --apply --format json     # machine-readable report
systemctl list-timers 'circuit-breaker-*'
journalctl -u circuit-breaker-sync -e
```

Set `flakeSync.reconcileInterval = "6h";` to repair manual drift of flake-owned fields on a
timer.

### Git-driven

```nix
flakeSync.git = { enable = true; url = "https://git.example.com/me/config.git"; ref = "main"; };
```

The timer (`flakeSync.interval`, default 5 min) resolves the ref with `git ls-remote`,
skips a revision it already synchronised, builds
`git+<url>?rev=<sha>#circuit-breaker-inventory` with `--no-update-lock-file`, validates it,
applies it and only then records the revision. Your downstream flake must export that package
(Campground does: `packages/circuit-breaker-inventory`). For a private repository set
`git.credentialFile` to a `git-credential-store` file delivered at runtime (never embed
credentials in the URL; the module rejects that).

```bash
sudo systemctl start circuit-breaker-sync-git.service
journalctl -u circuit-breaker-sync-git -e
sudo cb-sync --status     # last_success.revision, last_attempt
sudo -u circuit-breaker-sync jq .attempts /var/lib/circuit-breaker-sync/state.json   # failed revisions and next retry
```

A revision that fails to evaluate is retried with backoff and the last good topology stays.
To retry immediately after fixing the cause: `sudo cb-sync --sync-git --force`.

### What committing does and does not do

Committing to Git moves *desired* state once the git sync (or a deploy) runs. It does not
deploy anything. See "Three kinds of state" in the [architecture](CIRCUIT-BREAKER.md).

## 6. Retirement and cleanup

A machine removed from the flake is **tagged `nix:retired`** and its monitors are paused.
It stays on the map, with its history and any layout you gave it. To remove it, delete it in
the UI, or enable hard delete deliberately:

```nix
flakeSync.policy = { retire = "delete"; allowDelete = true; retireGraceDays = 30; };
```

If something retired reappears in the flake it is un-retired and its monitors resume.

An inventory that suddenly shrinks (a broken evaluation) exits 7 and changes nothing. If the
shrink is intended: `sudo cb-sync --apply --force-shrink`.

## 7. Hints (what the flake cannot know)

```nix
fmf.services.circuit-breaker.hints = {
  displayName = "Rack server";
  location = "garage"; rack = "U12";
  connections = [{ to = "core-switch"; type = "fiber"; bandwidthMbps = 10000; label = "sfp1"; }];
  devices.core-switch = { displayName = "Core switch"; role = "switch"; vendor = "ubiquiti"; address = "10.0.0.2"; };
  services.traefik.url = "https://proxy.lan.example.com";
  extraServices = [{ name = "idrac"; kind = "management"; port = 443; url = "https://10.0.0.5"; }];
  monitoring.enable = false;            # never monitor this host
};
```

`hints.ignore = true;` removes a system from the inventory. Only connections listed here
become `connects_to` edges.

## 8. Monitoring

Monitors are derived and synced automatically. They are CB's own ICMP/TCP/HTTP/DNS checks, so
no second monitoring stack is involved. CB runs them and records `up`/`down`; the flake only
says what to check. A new monitor shows `unknown` until its first run, and `POST
/api/v1/monitors/<id>/check` (or the UI's check-now) runs it immediately.

Tune: `monitoring.intervalSecs`, `monitoring.exclude = [ "mon/host/printer/*" ];`,
`monitoring.tcpKinds`, `monitoring.dnsQueryName`.

**Remote probes** run a check from an agent's network position (for example a segment the
server cannot reach):

```nix
monitoring.remoteProbes."mon/host/k8s-*" = "edge-agent-hostname";
```

The agent must be enrolled **and approved**; otherwise those monitors are skipped with a
warning, never run from the server. Removing the mapping returns the monitor to the server.

## 9. Agents

On a host that should report from its own vantage:

```nix
fmf.services.circuit-breaker.agent = {
  enable = true;
  serverUrl = "https://topology.lan.example.com";
  serverStaticPk = "…64 hex…";        # or serverStaticPkFile
  tlsPin = "…";                        # self-signed server only; or tlsPinFile
};
```

Get the two public values from the running server (the script is only *read*, never run):

```bash
curl -ksS https://topology.lan.example.com/install-agent.sh -o /tmp/ia.sh
sed -n 's/^CB_SERVER_STATIC_PK="\(.*\)"$/\1/p; s/^CB_TLS_PIN="\(.*\)"$/\1/p' /tmp/ia.sh
```

**Attended enrolment (default):** start the agent, run `cb-agent status` to read its
fingerprint, then in the UI (**Agents → pending**) compare the fingerprint and approve.
`local_discovery` is a separate grant you opt into at approval.

**Unattended:** mint a single-use token (**Agents → Add agent → Unattended**, max 24 h), put it
in a runtime file and set `agent.enrollTokenFile`. It is loaded as a systemd credential,
staged on tmpfs and erased by the agent after use. Approval is implied by the token, so keep
the lifetime and number of uses minimal.

The identity key lives in `/var/lib/cb-agent/device.key` (0600) and survives rebuilds;
restarts do not need re-approval. Revoke an agent in the UI; the agent then stays idle. To
re-enrol a host, stop the agent, delete `/var/lib/cb-agent`, and start it.

The agent only ever dials out. It needs no inbound firewall rule and has no updater: change
the package to upgrade it. If the server's identity key is rotated, update `serverStaticPk`.

## 10. Network discovery (opt-in)

Nothing is scanned by default. To authorise a bounded scan:

```nix
monitoring.discovery = {
  enable = true;
  profiles.lan = { cidr = "10.0.0.0/24"; scanTypes = [ "nmap" ]; schedule = "0 3 * * *"; nmapArguments = "-T3 --max-rate 100"; };
};
```

Rules enforced at evaluation time and again by the reconciler: private ranges only (unless
`allowPublicRanges`), no wider than /16, a valid 5-field cron or none (manual), `enable`
required. Profiles are named `nix: <name>` so repeated runs never create duplicates, and are
*disabled* (not deleted) when removed from the configuration. Discovered machines stay
separate from declared ones until they are matched by address, name or MAC.
Run once by hand from the UI (**Discovery**) to test a profile before scheduling it.

## 11. Backup

What matters: `<dataDir>/data` (database, uploads, TLS, vault-key file) **and**
`<dataDir>/secrets/server.env` (or wherever the secrets come from). Without the vault key,
stored credentials in a backup cannot be decrypted; with it, anyone can decrypt them, so
**snapshots are secrets**.

```bash
sudo systemctl start circuit-breaker-snapshot       # when backup.enable = true; daily 03:30 by default
sudo circuit-breaker-admin snapshot                  # prints the archive path (<dataDir>/data/backups/*.tar.gz, 0600)
```

The application also takes its own daily snapshot at 02:00. Copy snapshots off the host with
your usual encrypted backup (borg, restic), together with `server.env`.

Nothing here needs backing up for the *topology itself*: it is rebuilt from the flake.
What you lose without a backup is manual layout, notes, telemetry history, accounts, tokens
and enrolled agents.

## 12. Restore

File-level restore (the path used and reasoned about by this module):

1. `systemctl stop podman-circuit-breaker circuit-breaker-sync circuit-breaker-sync-git`
2. Restore `<dataDir>/data` and `<dataDir>/secrets/server.env` from backup, keeping the
   original numeric ownership (`rsync -a --numeric-ids` or your backup tool's equivalent;
   the data directory is owned by uid 1000 after first start).
3. `systemctl start podman-circuit-breaker`, wait for `circuit-breaker-ready`.
4. Re-run the sync: `sudo cb-sync --apply`. Ownership tags in the restored database make it
   a no-op for everything already there.

The upstream snapshot restore (`cb restore <archive>` inside the container) is **not
exercised by this repository's tests**; prefer the file-level path or read upstream's
backup guide first.

If you lose `server.env` but still have the data, the vault key can be recovered from
`<dataDir>/data/.env` (CB rotates it there), but the database password and JWT secret cannot
be guessed: restore the file.

## 13. Secret rotation

- **Sync token:** `sudo circuit-breaker-admin mint-sync-token` (the old secret stops working
  immediately; the next sync run uses the new file).
- **Server secrets** (`server.env`): do not edit casually; the database role password and the
  vault key are baked into stored data. Follow upstream's vault-key rotation procedure from
  the UI; update the stored `CB_VAULT_KEY` afterwards, then
  `systemctl restart circuit-breaker-env` (this restarts the container).
- **Agent enrolment tokens:** single-use and short-lived; revoke unused ones in the UI.

## 14. Upgrade and rollback

Upgrade Circuit Breaker (rare; the API is not stable between releases):

1. Read upstream's changelog for the target release.
2. Take a snapshot and copy it off the host (section 11).
3. Update `server.image` to the new digest (`skopeo inspect docker://ghcr.io/blkleg/circuitbreaker:<tag>`
   shows it) and the agent source pin in `packages/circuit-breaker-agent`.
4. Re-run the tests: `nix build .#checks.x86_64-linux.circuit-breaker-sync` (update
   `tests/fixtures/openapi-*-subset.json` from the new release's `/api/openapi.json`) and the
   VM test (`…circuit-breaker-vm`). Update `TESTED_CB_VERSION` in `cb_sync/__init__.py`.
   The reconciler refuses a different minor version until you do (or set
   `allowUntestedVersion` temporarily and watch `cb-sync --dry-run`).
5. Deploy. The app migrates its schema on start (`/readyz` reports `ready` afterwards).

Rollback: set `server.image` back to the previous digest and deploy. **A schema migration is
not reversible by the image alone**: if the new version already migrated the database, restore
the pre-upgrade snapshot (section 12) before starting the old image.

Rolling back the NixOS generation is safe for the reconciler: the next sync reapplies the
older declared state and tags what is no longer declared as retired.

Upgrade the reconciler or exporter: ordinary NixOS deploys. The inventory schema is versioned
(`schemaVersion`); the reconciler refuses versions it does not know (exit 6).

## 15. Routine checks

```bash
circuit-breaker-admin status
sudo cb-sync --status --live
systemctl --failed | grep circuit
journalctl -u circuit-breaker-sync -u circuit-breaker-sync-git --since -1d
curl -ksS https://<server>:8443/api/v1/health | jq     # liveness + dependency state
```
