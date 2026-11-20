---
type: NixOS Module
title: Uptime Kuma (fmf.services.uptime-kuma)
description: Runs Uptime Kuma and keeps its monitors in sync with Nix - hand-written monitors plus one per enabled Traefik route, added, updated and deleted on deploy.
resource: ./default.nix
tags: [services, uptime-kuma, monitoring, traefik]
generated: { by: claude-agent/opus-5-5, at: 2026-11-19T22:00:00-06:00 }
status: draft
---

# Uptime Kuma (`fmf.services.uptime-kuma`)

Runs [Uptime Kuma](https://github.com/louislam/uptime-kuma) and, optionally, manages its
monitors from Nix. Day-to-day procedures are in the
[Uptime Kuma runbook](../../../../docs/UPTIME-KUMA-RUNBOOK.md).

## Files

| File | What it is |
| --- | --- |
| `default.nix` | The module: the server, the `monitors` option, Traefik discovery and the provisioning unit. |
| `traefik.nix` | Pure Nix: turns other hosts' Traefik routers into monitors. |
| `provision.js` | The reconciler. Talks to Kuma's own Socket.IO API (the one the web UI uses). |

## Why a provisioner

Uptime Kuma has no configuration file for monitors: they live only in its database and can only
be changed through its live API. So the module writes the wanted monitors to a JSON file at build
time, and a systemd unit, `uptime-kuma-provision`, logs in after Kuma starts and makes the
database match.

It uses the `socket.io-client` bundled inside the Uptime Kuma package, so client and server
always come from the same release. The Python `uptime-kuma-api` in nixpkgs targets Kuma 1.x and
is not used.

## Ownership: the `nix` tag

Every monitor the provisioner creates gets the tag `nix` (`provision.tag`), whose **value is the
monitor's key** in `monitors`. On every run:

| State | Action |
| --- | --- |
| Key in `monitors`, no tagged monitor | Add it and tag it. |
| Key in `monitors`, tagged monitor exists | Update it if any managed field differs. |
| Tagged monitor, key no longer in `monitors` | **Delete it** (its history goes with it). |
| Monitor without the tag (made in the UI) | Never touched. |

Do not edit a managed monitor in the UI: the next run puts the managed fields back. Fields the
module does not set (notifications, for example) are kept, because an update starts from the
monitor as Kuma has it. Changing `provision.tag` orphans every existing managed monitor (they stay,
unmanaged); delete them by hand afterwards.

## Traefik discovery

`traefik.enable = true` adds one HTTP monitor per **enabled Traefik route** of the hosts in
`traefik.hosts`, keyed `<label>/<router>`. It reads each host's evaluated
`services.traefik.dynamicConfigOptions.http`:

- **Which routers:** a rule made only of `Host(...)` terms joined by `||`. The first host name is
  checked. Sub-routes (`Host(...) && PathPrefix(...)`), `HostRegexp(...)` and TCP routers are
  skipped; the plain host route covers that name.
- **Enabled:** the router's service is internal (`api@internal`), or not a load balancer
  (weighted, mirroring, failover), or a load balancer with **at least one server**. An empty server
  list is what `lib.fmf.lookupServiceEndpoint` produces when no host enables the service, so that
  route is skipped. A router whose service does not exist is skipped too.
- **Scheme:** `https://` if the router listens on an entry point in `httpsEntryPoints` (or names
  none), otherwise `http://`.
- **Up:** status `200-399`, `401` or `403` (`traefik.acceptedStatusCodes`). A login page or an
  auth redirect means the service answered.

Every discovered field is a `mkDefault`, so you can change one monitor by writing the same key:

```nix
fmf.services.uptime-kuma.monitors."lan/vault".url = "https://vault.example.lan/v1/sys/health";
```

`traefik.exclude = ["lan/some-router"];` drops a discovered monitor (and so deletes it from Kuma).

**`traefik.nixosConfigurations` is required.** Inside a module exported from fmf, `inputs.self` is
fmf itself, not the flake that imports it, so the module cannot find your hosts on its own; it would
read fmf's example hosts (some share names with real ones). Pass your flake's:
`nixosConfigurations = inputs.self.nixosConfigurations;`. An assertion fails if it is empty.

## Options

| Option | Default | Meaning |
| --- | --- | --- |
| `enable` | `false` | Run Uptime Kuma. |
| `port` | `4000` | Listen port (on `0.0.0.0`). |
| `openFirewall` | `true` | Open the port on every interface. Set `false` on multi-homed hosts and open it per interface. |
| `monitors.<key>` | `{}` | Managed monitors. Fields: `name` (default: the key), `type` (`http`), `url`, `hostname`, `port`, `interval` (60), `retryInterval` (60), `maxretries` (2), `acceptedStatusCodes` (`["200-299"]`), `ignoreTls`, `description`, and `settings` (raw Kuma fields merged on top). Each needs a `url` or a `hostname`. |
| `traefik.enable` | `false` | Add monitors from Traefik routes (above). |
| `traefik.hosts` | `{}` | Label to host name, e.g. `{ lan = "lan-proxy"; public = "public-proxy"; }`. |
| `traefik.nixosConfigurations` | `{}` | Required: your flake's `inputs.self.nixosConfigurations`. |
| `traefik.httpsEntryPoints` | `["websecure"]` | Entry points served over HTTPS. |
| `traefik.exclude` | `[]` | Discovered keys to leave out. |
| `traefik.acceptedStatusCodes` | `200-299 300-399 401 403` | Up codes for discovered monitors. |
| `traefik.interval` | `60` | Check interval for discovered monitors. |
| `provision.enable` | `monitors != {}` | Run the reconciler. |
| `provision.tag` | `"nix"` | Tag marking managed monitors. |
| `provision.vault-path` | `secret/campground/uptime-kuma` | KV path with the admin credentials. |
| `provision.usernameField` / `passwordField` | `username` / `password` | Fields at that path. |
| `provision.kvVersion` | `v2` | KV engine version. |
| `provision.usernameFile` / `passwordFile` | `null` | Set both to read the credentials from files instead of Vault. |
| `provision.role-id` / `secret-id` / `vault-address` | from `fmf.services.vault-agent` | AppRole login for the sidecar. |

## The provisioning unit

- `uptime-kuma-provision.service`, after and `PartOf` `uptime-kuma.service`: when Kuma restarts,
  the monitors are applied again.
- `Type=simple` with `RemainAfterExit`, so `nixos-rebuild switch` neither waits for it nor fails
  because of it (a slow Kuma or an unreachable Vault cannot roll back a deploy). It restarts on
  failure every 2 minutes, without a limit.
- The monitor JSON is a restart trigger: a deploy that changes the monitors re-runs it.
- **First run on an empty Kuma:** it creates the admin account from the Vault credentials (the
  browser setup page is skipped). Kuma rejects passwords it rates "Too weak".
- **2FA on the admin account blocks it** (it logs in with a password only).
- Credentials: a vault-agent sidecar (`detsys-vaultAgent-uptime-kuma-provision`) renders
  `kuma-username` and `kuma-password` into the unit's private `/tmp/detsys-vault/`. The files are
  read on every run, so rotating the password needs no restart. The host's AppRole needs read
  access to `provision.vault-path`; `vault-access` generates that policy
  (`svc-uptime-kuma-provision`).

- `uptime-kuma-plan` (installed with the unit): the same reconciler and monitor list with dry run
  forced on. It prints what a run would add, update and delete and changes nothing. It needs
  the credentials as files: see the runbook, "Preview a change".

## Example

```nix
{inputs, ...}: {
  fmf.services.uptime-kuma = {
    enable = true;
    traefik = {
      enable = true;
      nixosConfigurations = inputs.self.nixosConfigurations;
      hosts = { lan = "vm-lan-traefik"; public = "vm-pub-traefik"; };
      exclude = ["lan/flaky-thing"];
    };
    monitors.nas-ssh = { type = "port"; hostname = "192.168.50.20"; port = 22; };
  };
}
```

## What was tested

Against a throwaway Uptime Kuma 2.5.8 (the nixpkgs version at the time) on a fresh database:
first-run setup started at the same moment as Kuma (startup race), add, an idempotent rerun, a dry
run, update of a changed field, deletion of a removed key, an untagged monitor left alone, a wrong
password (exit 1), and the full 60-monitor list generated from a real two-proxy fleet (60 added,
rerun 60 unchanged). Not yet tested: a live deploy through the unit and the Vault sidecar, and Kuma
with MariaDB.

## Not done yet

- **Notifications.** Kuma's email (SMTP) notification will be added declaratively next; until
  then, notifications attached by hand in the UI survive provisioning.
- Status pages and maintenance windows are not managed.
