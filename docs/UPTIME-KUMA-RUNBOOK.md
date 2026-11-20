---
type: Runbook
title: Uptime Kuma runbook - declarative monitors
description: First-time setup, adding and removing monitors, previewing a change, credential rotation, recovery, moving to another host and troubleshooting for Uptime Kuma whose monitors are provisioned from Nix and Traefik routes.
tags: [uptime-kuma, monitoring, traefik, vault, runbook, operations]
generated: { by: claude-agent/opus-5-5, at: 2026-11-19T22:00:00-06:00 }
status: draft
---

# Uptime Kuma runbook

How to run Uptime Kuma when its monitors come from Nix. What the module does and every option:
[module README](../modules/nixos/services/uptime-kuma/README.md). Vault procedures in general:
[Vault runbook](VAULT-RUNBOOK.md).

`status: draft`. The reconciler was exercised against a real Uptime Kuma 2.5.8 (see the module
README, "What was tested"). The procedures below that involve a live deploy, the Vault sidecar
and `vault-access` follow the fleet's existing patterns but had not been run end to end when this
was written. Placeholders: `<kuma-host>` is the host running Kuma, `<flake>` the downstream flake
root.

## The model in five lines

| Thing | Where it lives |
| --- | --- |
| Wanted monitors | `fmf.services.uptime-kuma.monitors` on `<kuma-host>`, plus one per enabled Traefik route when `traefik.enable` is on. Built into a JSON file. |
| Real monitors | Kuma's database (`/var/lib/uptime-kuma/`). The UI and the reconciler both write here. |
| Ownership | Tag `nix` with the monitor's key as its value. Tagged = managed by Nix; untagged = yours, never touched. |
| Reconciler | `uptime-kuma-provision.service` on `<kuma-host>`. Runs after Kuma starts, after every deploy that changes the list, and when Kuma restarts. |
| Credentials | Vault KV `secret/campground/uptime-kuma`, fields `username` and `password`. Rendered by the sidecar `detsys-vaultAgent-uptime-kuma-provision`. |

## 1. First-time setup

Do these in order. Step 4 deploys; everything before it is preparation.

1. **Write the admin credentials to Vault.** If Kuma is already set up, use the **existing** admin
   username and password (the reconciler logs in with them). If it is a fresh install, pick new
   ones: the reconciler creates the account. Kuma refuses passwords it rates "Too weak", so use a
   long random one:

   ```bash
   pw=$(openssl rand -base64 30)
   printf %s "$pw" | vault kv put -mount=secret/campground uptime-kuma username=admin password=-
   unset pw
   vault kv get -mount=secret/campground uptime-kuma   # check both fields exist
   ```

   Turn off 2FA on that account if it is on: the reconciler cannot answer a 2FA prompt.

2. **Enable it on `<kuma-host>`** (downstream flake):

   ```nix
   fmf.services.uptime-kuma = {
     enable = true;
     traefik = {
       enable = true;
       nixosConfigurations = inputs.self.nixosConfigurations;  # required, see the module README
       hosts = { lan = "vm-lan-traefik"; public = "vm-pub-traefik"; };
     };
   };
   ```

   The host needs `fmf.services.vault-agent` enabled (it already has it if it reads any other
   secret from Vault).

3. **Check what it will monitor and give it Vault access**, from `<flake>`:

   ```bash
   nix eval --json .#nixosConfigurations.<kuma-host>.config.fmf.services.uptime-kuma.monitors \
     --apply 'builtins.mapAttrs (_: m: m.url)' | jq
   vault-access                    # adds svc-uptime-kuma-provision to <kuma-host>'s generated policies
   vault-access --fix              # dry run: should show only that policy and <kuma-host>'s role
   vault-access --fix --apply      # needs VAULT_ADDR and an admin token
   git add systems/x86_64-linux/vm-vault/vault && git commit
   ```

   If the list has a monitor you do not want, add its key to `traefik.exclude` and evaluate again.

4. **Deploy `<kuma-host>`**, then watch the first run:

   ```bash
   ssh <kuma-host> 'journalctl -u uptime-kuma-provision -f'
   ```

   A good first run ends with `N added, 0 updated, 0 unchanged, 0 deleted` and the unit stays
   `active (exited)`. In the UI, managed monitors show the `nix` tag.

## 2. Day to day

**A service is added or removed behind Traefik.** Nothing to do in Kuma. Deploy the Traefik host
as usual, then deploy `<kuma-host>`: discovery reads the Traefik host's evaluated config, so
`<kuma-host>` must be rebuilt for the monitor list to change. A route whose service has no backend
(nobody enables it) disappears from the list, and its monitor and its history are deleted.

**Add a monitor that is not a Traefik route:**

```nix
fmf.services.uptime-kuma.monitors.nas-ssh = { type = "port"; hostname = "10.0.0.20"; port = 22; };
```

**Change one discovered monitor** by writing the same key (discovered fields are defaults):

```nix
fmf.services.uptime-kuma.monitors."lan/vault".url = "https://vault.example/v1/sys/health";
```

**Stop monitoring a route:** `traefik.exclude = ["lan/<router>"];` (its monitor is deleted).

**Keep a monitor through a removal** (keep its history): before deploying, remove the `nix` tag
from it in the UI. It is then yours and will not be deleted.

**Monitors you make in the UI** are never touched. Do not edit managed ones in the UI: the next run
reverts the managed fields.

## 3. Preview a change

Evaluate the list before deploying (step 3 above), or, on `<kuma-host>` after a deploy, ask the
reconciler what it would do without changing anything:

```bash
ssh <kuma-host>
export VAULT_ADDR=https://vault.example; vault login   # any token that can read the secret
KUMA_USERNAME_FILE=<(vault kv get -mount=secret/campground -field=username uptime-kuma) \
KUMA_PASSWORD_FILE=<(vault kv get -mount=secret/campground -field=password uptime-kuma) \
  uptime-kuma-plan
```

It prints one line per add, update (with the fields that differ) and delete, then the totals.

## 4. Re-run the reconciler

```bash
ssh <kuma-host> 'sudo systemctl restart uptime-kuma-provision && journalctl -u uptime-kuma-provision -n 20'
```

Safe at any time: a run with nothing to do ends `0 added, 0 updated, N unchanged, 0 deleted`.

## 5. Rotate the admin password

The reconciler logs in with whatever is in Vault, so Vault and Kuma must change together:

1. In the Kuma UI: Settings, Security, change the password.
2. Write the same password to Vault (`vault kv patch -mount=secret/campground uptime-kuma password=-`).
3. Re-run the reconciler (section 4). The sidecar re-renders the file and the reconciler reads it on
   each run; no other restart is needed.

Between steps 1 and 2 a run fails with `login failed: authIncorrectCreds` and retries every two
minutes; it recovers by itself after step 2.

## 6. Recovery

**Lost the Kuma database.** Deploying (or restarting `uptime-kuma`) on an empty database is a fresh
install: the reconciler creates the admin account from Vault and every managed monitor again. UI
monitors, history and notifications are gone; restore them from a backup of `/var/lib/uptime-kuma/`.

**Turn provisioning off** without losing monitors: `provision.enable = false;` and deploy. The
monitors stay in Kuma as they are (still tagged); nothing deletes them.

**Remove all managed monitors:** set `traefik.enable = false;` and no `monitors`, but keep
`provision.enable = true;` explicitly (its default turns off with an empty list), deploy once, then
remove it.

## 7. Move Uptime Kuma to another host

The Traefik backend follows by itself (`lookupServiceEndpoint` finds whichever host enables the
service), and the reconciler recreates every managed monitor on the new host. What does not follow
by itself: history, monitors made in the UI, notifications, and the Vault policy.

1. **Decide on the data.**
   - **Start fresh** (simplest): skip step 3. Managed monitors are recreated; history and UI monitors are lost.
   - **Keep it**: copy the database (step 3). If the old instance has **untagged** monitors for the
     same sites (made by hand before provisioning), you will get duplicates next to the new tagged
     ones; delete the untagged ones in the UI afterwards.
2. **Change the flake:** enable `fmf.services.uptime-kuma` (with `traefik.*`) on the new host, remove
   it from the old one, then `vault-access` so the new host's role gets `svc-uptime-kuma-provision`
   (and the old one loses it), `vault-access --fix --apply`, and commit. For a MicroVM, add a
   storage share for `/var/lib/uptime-kuma` and run `fleet`.
3. **Copy the database before the new host first starts Kuma.** The nixpkgs unit uses `DynamicUser`,
   so on an ordinary host the data is in `/var/lib/private/uptime-kuma/`:

   ```bash
   ssh <old-host> 'sudo systemctl stop uptime-kuma'
   ssh <old-host> 'sudo tar -C /var/lib/private/uptime-kuma -cf - .' \
     | ssh <new-data-host> 'sudo install -d -m 0700 <data-dir> && sudo tar -C <data-dir> -xf -'
   ```

   `<new-data-host>`/`<data-dir>` is where the new host's `/var/lib/uptime-kuma` really lives (for
   a MicroVM, its hypervisor and the share's host path). Ownership is fixed by systemd when Kuma
   starts (it chowns the state directory to the service user). Both hosts must run the same Uptime
   Kuma version, or the newer one migrates the database on first start (no way back).
4. **Deploy the old host first** (Kuma stops there), then the new one, then the Traefik host if its
   configuration changed. Watch `journalctl -u uptime-kuma-provision -f` on the new host: with a
   copied database, managed monitors that already exist show as `unchanged` or `update`, not `add`.
5. **Clean up** the old data directory once the new instance looks right.

## 8. Troubleshooting

| Symptom (in `journalctl -u uptime-kuma-provision`) | Cause and fix |
| --- | --- |
| `cannot reach Uptime Kuma at http://127.0.0.1:4000` | Kuma is not up. `systemctl status uptime-kuma`. The reconciler waits up to 5 minutes, then retries every 2. |
| `connected, but Kuma sent no info within 15s` | Kuma is still starting (migrations on a big database). It reconnects until the 5-minute wait runs out. |
| `login failed: authIncorrectCreds` | Vault and Kuma disagree on the password. Section 5. Several failures in a row trigger Kuma's login rate limit; wait a minute. |
| `the admin account has 2FA enabled` | Turn 2FA off for that account (the reconciler cannot use it). |
| `initial setup failed: passwordTooWeak` | Fresh install with a weak password in Vault. Write a stronger one (section 1). |
| `KUMA_USERNAME_FILE ... ENOENT` / sidecar failed | The sidecar could not render the secret: `systemctl status detsys-vaultAgent-uptime-kuma-provision`. Usually the AppRole lacks `svc-uptime-kuma-provision` (rerun `vault-access --fix --apply`) or the secret is missing. |
| `add <key> failed: ...` | Kuma rejected a monitor's fields. The message is Kuma's; fix that monitor's options. Other monitors already applied stay applied. |
| A monitor is down but the site works in a browser | Discovered monitors accept `200-399`, `401`, `403`. A service that answers something else (404 at `/`, 5xx behind auth) needs its own `url` or `acceptedStatusCodes` (section 2). An internal-CA certificate needs `ignoreTls = true` on that monitor or the CA trusted on `<kuma-host>`. |
| Monitor list is missing routes, or has strange ones | `traefik.nixosConfigurations` points at the wrong flake (fmf's example hosts). It must be your flake's `inputs.self.nixosConfigurations`. |
