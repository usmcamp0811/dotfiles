---
type: Troubleshooting
title: Circuit Breaker troubleshooting
description: Exit codes, symptoms and fixes for the Circuit Breaker server, reconciler, git-driven sync, agents and monitors.
tags: [circuit-breaker, troubleshooting]
generated: { by: claude-agent/sonnet-5-5, at: 2026-11-01T12:00:00Z }
---

# Circuit Breaker troubleshooting

See the [runbook](CIRCUIT-BREAKER-RUNBOOK.md) for procedures and the
[architecture](CIRCUIT-BREAKER.md) for the model.

## Reconciler exit codes

| Code | Meaning | What to do |
| --- | --- | --- |
| 0 | Success (or nothing to do) | |
| 1 | Unexpected error, bad usage, unreadable state file | Read the message; state file ownership: `ls -l /var/lib/circuit-breaker-sync` |
| 2 | Invalid inventory or policy | `cb-sync --validate`; the message lists the first problems. A secret-looking key or value is rejected here |
| 3 | Authentication or authorisation | Token missing, expired, revoked or rotated. `sudo circuit-breaker-admin mint-sync-token` |
| 4 | Server unreachable after retries | Is the API up? `circuit-breaker-admin status`; certificate pin mismatch also lands here |
| 5 | Partial failure | Some operations failed; **safe to re-run**. Retirement is skipped in a run with errors. See the `error` lines |
| 6 | Incompatible server or schema | OpenAPI missing an operation/field, a different CB minor version, or an unknown inventory `schemaVersion`. See the runbook's upgrade section |
| 7 | Safety guard | Empty inventory or large shrink. Look at why the evaluation shrank; `--force-shrink` only if intended |
| 10 | Changes pending (`--dry-run --detailed-exitcode`) | Informational |

The units do not retry codes 2, 3, 6 and 7 (`RestartPreventExitStatus`).

## Server

The stack is plain systemd units; `circuit-breaker-admin status` lists them all.
Start/stop everything with `systemctl start|stop circuit-breaker.target`. Order is
`env` -> `postgres` (+ `redis`, `nats`) -> `migrate` -> `api` and the `worker-*` units -> `ready`.

**`circuit-breaker-ready` never succeeds** – find the first unit that failed:
`systemctl --failed | grep circuit`, then `journalctl -u <unit> -e`.

| Unit | Symptom | Cause / fix |
| --- | --- | --- |
| `circuit-breaker-env` | `does not define CB_…` | The external or Vault-rendered file lacks one of `CB_DB_PASSWORD`, `CB_VAULT_KEY`, `CB_JWT_SECRET`, `NATS_AUTH_TOKEN`. |
| `circuit-breaker-env` | `must be at least 32 characters`, `must differ`, `may only contain …` | `CB_JWT_SECRET` and `NATS_AUTH_TOKEN` need 32+ characters, the vault key must differ from the JWT secret, and the NATS token is limited to letters, digits and `. _ ~ + / = -` (it is written, quoted, into a config file). |
| `circuit-breaker-postgres` | `password authentication failed` from `migrate`/`api` | The cluster was initialised with a different `CB_DB_PASSWORD` than the one now staged. The role password is fixed at first initialisation: run `ALTER ROLE breaker PASSWORD '…'` through a working connection, or restore the matching `server.env`. |
| `circuit-breaker-postgres` | `could not load library "timescaledb"` / unfree package error at build time | TimescaleDB is under the Timescale licence: allow it (`nixpkgs.config.allowUnfree = true`). |
| `circuit-breaker-postgres` | `Permission denied` on the data directory | The state tree must belong to `server.uid` (default 1500); after restoring from backup use `--numeric-ids`. A MicroVM share that remaps ids breaks this. |
| `circuit-breaker-migrate` | alembic error | `journalctl -u circuit-breaker-migrate`. A failed migration leaves the API stopped; fix, then `systemctl restart circuit-breaker-migrate`. |
| `circuit-breaker-api` | `CB_EGRESS_PROXY_URL is required in production…` | Set `server.egress.allowDirect` (default true) or `proxyUrl`; the app refuses to start with neither. |
| `circuit-breaker-api` | `address already in use` | Something else holds `server.port`. Pick another. |
| `circuit-breaker-nats` | config parse error | Never supply the NATS token through a variable in a config file: the module writes it quoted into `/run/circuit-breaker-nats/nats.conf`. |
| any worker | restart loops | `journalctl -u circuit-breaker-worker-<name>`; usually Redis/NATS not yet up (they start in seconds) or the database unreachable. |

**Everything restarted after `systemctl restart circuit-breaker-env`**
Intended: every service `Requires` the staged secrets, and Redis gets a new password at each start.

**`setup-token` says setup is complete**
Correct: tokens are only valid until the first administrator exists. Reset an administrator with `circuit-breaker-admin cli user …` (see `cli user --help`).

**`Vault is not initialized` from a script you run by hand**
The credential vault is unlocked by the API at startup. Standalone scripts must do
`get_vault().reinitialize(vault_service.load_vault_key(db))` first (see `circuit-breaker-admin agent-key`).
After first-run setup the effective vault key is in `<dataDir>/data/.env`, not the `CB_VAULT_KEY` you supplied.

**`/install-agent.sh` returns 500 "Cannot obtain TLS pin"**
Upstream derives agent pins from `<dataDir>/data/tls/fullchain.pem`. With `server.tls.*` the module
publishes the certificate there; with plain HTTP behind a proxy there is none, so read the public key
with `circuit-breaker-admin agent-key` instead (agents behind a proxy with a trusted certificate need no pin).

**TLS: reverse proxy shows 502/handshake errors**
With `server.tls.*` unset the API speaks plain HTTP: point the proxy at `http://` and do not enable TLS to the backend. With `server.tls.*` set it speaks HTTPS: use `https://` and either trust the certificate or pin it.

**UI loads but websockets/agents fail behind a proxy**
Add the proxy address to `server.trustedProxyCidrs` (loopback is already trusted) and make sure it forwards `Upgrade` headers and `X-Forwarded-*`.

## Provisioning and the sync token

**Sync units show "skipped, unmet condition"** – the token file does not exist yet. Finish first-run setup (`circuit-breaker-admin setup-token`); `circuit-breaker-provision` then mints the token within a minute. Check `journalctl -u circuit-breaker-provision`.

**`circuit-breaker-provision` says "first-run setup is not complete"** – expected until the administrator is created through the UI.

**Token exists but the sync gets 401** – it was revoked or rotated elsewhere. `sudo circuit-breaker-admin mint-sync-token`.

## Reconciler behaviour

**Everything shows `create` every run** – ownership tags are not being read back. Look for the entity's tags in the UI (`nix:id:…`). If someone stripped them, the entity is treated as unmanaged and will be adopted by name/address on the next run.

**"several unmanaged entities match; not adopting"** – two manual entries share a name/address with something declared. Rename or tag one by hand; the declared item is skipped, not duplicated.

**"ip_address X is already used by Y; synced without it"** – the flake declares one address on two machines (the exporter also emits `duplicate_address`). Fix the flake. The entity exists without the IP meanwhile.

**A container is missing its IP** – containers declared on a host (for example `virtualisation.oci-containers`) that only publish ports share the host's address; CB rejects duplicate IPs, so the address is intentionally not recorded for them.

**Entity kept after removal from the flake** – by design (`nix:retired`). See runbook section 6.

**A monitor was skipped: "probe agent … unavailable"** – the agent named in `monitoring.remoteProbes` is not enrolled and *approved* (match is on the agent's name or host name).

**Layout/notes changed after a sync?** They should never be. Open an issue with `cb-sync --dry-run --format json` output; the reconciler writes only the flake-owned fields listed in the architecture.

**`state.json` unreadable** – happens if a different account wrote it. Files are shared with the state directory's group (mode 0660). `sudo chgrp circuit-breaker-sync /var/lib/circuit-breaker-sync/state.json; sudo chmod 660 …`. The reconciler refuses to reset state silently.

## Git-driven sync

| Symptom | Cause |
| --- | --- |
| `git ls-remote failed` | Credentials/URL/network. `sudo -u circuit-breaker-sync git ls-remote <url> refs/heads/<ref>` with the credential file; `git.credentialFile` must be a `git-credential-store` file |
| `nix build failed for <sha>` | Evaluation or build error in that revision. The journal shows the last lines. Fix, push; it is retried (backoff 5 min → 6 h). `cb-sync --sync-git --force` retries now |
| `flake … does not provide attribute …circuit-breaker-inventory` | The downstream flake does not export `packages.<system>.circuit-breaker-inventory` (or `git.attr` is wrong), or that revision is not tracked by git |
| "already synchronised" | Nothing to do: that revision was applied |
| Inventory fine, nothing changes | Another source (deployment-driven) wrote the same state; the most recent run wins |

The unit runs as an unprivileged user with `HOME=/var/lib/circuit-breaker-sync`; nix caches
live there. Large first evaluations need `buildTimeoutSecs`.

## Agents

| Symptom | Fix |
| --- | --- |
| `cb-agent.service` skipped | `serverStaticPkFile` does not exist yet (ConditionPathExists) |
| `server_static_pk is not 64 hex characters` / `tls_pin is not a base64 SHA-256 digest` | Wrong value copied; re-read with `circuit-breaker-admin agent-key` (key) or compute the pin from the served certificate |
| Stays `pending` | Approve it in the UI; check the fingerprint with `cb-agent status` |
| `link: tls trust matched policy` missing, handshake errors | TLS pin stale (server certificate regenerated): update `tlsPin`/`tlsPinFile`. Time skew over 60 s also fails |
| Rejected/revoked | Re-enrol (runbook section 9) |
| Discovery/probes do nothing | Capability not granted at approval, or target is outside the agent's directly connected private networks (the agent refuses out-of-scope targets by design) |
| "refusing to start: … is owned by uid" | Do not run `cb-agent` by hand as another user against `/var/lib/cb-agent` |

## Monitors show `down` for things that are up

Remember who runs the check: the **server's workers**, from the server's network position,
unless a remote probe is assigned. A host the *server* cannot reach from its
network position, or a firewall that only allows other sources, will look down. Test from
from the server host: `nc -zv <host> <port>` (as the `circuit-breaker` user for firewall rules scoped to it). Assign the monitor to an
agent on the right segment. HTTPS monitors verify certificates by default
(`monitoring.httpVerifyTls`).

## Collect information for a bug report

```bash
circuit-breaker-admin status
sudo cb-sync --validate --format json | jq .inventory
sudo cb-sync --dry-run --format json > /tmp/dry.json     # contains no secrets
systemctl status circuit-breaker-* cb-agent --no-pager
journalctl -u 'circuit-breaker-*' --since -2h --no-pager
```

Do not attach `server.env`, snapshots, tokens, or an unredacted unit environment dumps.
