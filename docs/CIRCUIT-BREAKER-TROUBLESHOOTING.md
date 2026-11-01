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
| 4 | Server unreachable after retries | Is the container up? `circuit-breaker-admin status`; certificate pin mismatch also lands here |
| 5 | Partial failure | Some operations failed; **safe to re-run**. Retirement is skipped in a run with errors. See the `error` lines |
| 6 | Incompatible server or schema | OpenAPI missing an operation/field, a different CB minor version, or an unknown inventory `schemaVersion`. See the runbook's upgrade section |
| 7 | Safety guard | Empty inventory or large shrink. Look at why the evaluation shrank; `--force-shrink` only if intended |
| 10 | Changes pending (`--dry-run --detailed-exitcode`) | Informational |

The units do not retry codes 2, 3, 6 and 7 (`RestartPreventExitStatus`).

## Server

**`circuit-breaker-ready` never succeeds**
`journalctl -u podman-circuit-breaker -e`. Common causes:
- `CB_EGRESS_PROXY_URL is required in production…` – set `server.egress.allowDirect` (default true) or `proxyUrl`; the app refuses to start with neither.
- `No space left on device` from `crun` – podman's `tmpcopyup` copying the image into a small tmpfs. The module sets `notmpcopyup`; if you added your own `--tmpfs` for podman, add it too.
- `parsing file "/run/circuit-breaker-secrets/server.env": no such file` – the secrets unit did not run or failed: `systemctl status circuit-breaker-env`. Check the source (`secrets.generate`, file, or Vault render).
- The secrets directory must not equal the container's `RuntimeDirectory` (systemd deletes that when the container unit restarts). The module uses a separate one.

**`circuit-breaker-env` fails with "does not define CB_…"**
The external or Vault-rendered file lacks one of `CB_DB_PASSWORD`, `CB_VAULT_KEY`, `CB_JWT_SECRET`, `NATS_AUTH_TOKEN`. `CB_JWT_SECRET` and `NATS_AUTH_TOKEN` need 32+ characters, and the vault key must differ from the JWT secret.

**Curl to the UI hangs for minutes right after a restart**
A rootful podman port mapping can swallow SYNs while the container is down. Use `--max-time` in scripts.

**`setup-token` says setup is complete**
Correct: tokens are only valid until the first administrator exists. Reset an administrator with `circuit-breaker-admin cli user …` (see `cli user --help`).

**After `systemctl restart circuit-breaker-env` the container restarted**
Intended: the container `Requires` its secrets unit.

**TLS: reverse proxy shows 502/handshake errors**
The container serves HTTPS only and its default certificate is self-signed. Configure the proxy to skip verification for that hop, or set `server.tls.certFile/keyFile`.

**UI loads but websockets/agents fail behind a proxy**
Add the proxy address to `server.trustedProxyCidrs` and make sure it forwards `Upgrade` headers and `X-Forwarded-*`.

## Provisioning and the sync token

**Sync units show "skipped, unmet condition"** – the token file does not exist yet. Finish first-run setup (`circuit-breaker-admin setup-token`); `circuit-breaker-provision` then mints the token within a minute. Check `journalctl -u circuit-breaker-provision`.

**`circuit-breaker-provision` says "first-run setup is not complete"** – expected until the administrator is created through the UI.

**Token exists but the sync gets 401** – it was revoked or rotated elsewhere. `sudo circuit-breaker-admin mint-sync-token`.

## Reconciler behaviour

**Everything shows `create` every run** – ownership tags are not being read back. Look for the entity's tags in the UI (`nix:id:…`). If someone stripped them, the entity is treated as unmanaged and will be adopted by name/address on the next run.

**"several unmanaged entities match; not adopting"** – two manual entries share a name/address with something declared. Rename or tag one by hand; the declared item is skipped, not duplicated.

**"ip_address X is already used by Y; synced without it"** – the flake declares one address on two machines (the exporter also emits `duplicate_address`). Fix the flake. The entity exists without the IP meanwhile.

**A container is missing its IP** – containers that only publish ports on the host share the host's address; CB rejects duplicate IPs, so the address is intentionally not recorded for them.

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
| `server_static_pk is not 64 hex characters` / `tls_pin is not a base64 SHA-256 digest` | Wrong value copied; re-extract from `install-agent.sh` |
| Stays `pending` | Approve it in the UI; check the fingerprint with `cb-agent status` |
| `link: tls trust matched policy` missing, handshake errors | TLS pin stale (server certificate regenerated): update `tlsPin`/`tlsPinFile`. Time skew over 60 s also fails |
| Rejected/revoked | Re-enrol (runbook section 9) |
| Discovery/probes do nothing | Capability not granted at approval, or target is outside the agent's directly connected private networks (the agent refuses out-of-scope targets by design) |
| "refusing to start: … is owned by uid" | Do not run `cb-agent` by hand as another user against `/var/lib/cb-agent` |

## Monitors show `down` for things that are up

Remember who runs the check: the **server** (inside the container, on the container
network path) unless a remote probe is assigned. A host the *container* cannot reach from its
network position, or a firewall that only allows other sources, will look down. Test from
inside: `podman exec circuit-breaker sh -c 'nc -zv <host> <port>'`. Assign the monitor to an
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

Do not attach `server.env`, snapshots, tokens, or an unredacted `podman inspect`.
