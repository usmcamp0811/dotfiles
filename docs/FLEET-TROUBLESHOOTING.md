---
type: Troubleshooting
title: Fleet troubleshooting - errors, warnings and symptoms
description: What each fleet error and warning means and how to fix it, plus the common ways a flake, a MicroVM or the generated files go wrong - messages quoted from real runs.
tags: [fleet, hosts, troubleshooting, microvm, network]
status: draft
---

# Fleet troubleshooting

Find the text you saw, then read across. Procedures are in the [runbook](FLEET-RUNBOOK.md); the first-time setup is
in [Getting started](FLEET-GETTING-STARTED.md).

`fleet` **stops and writes nothing** when it finds an error: it prints `the fleet has N error(s); nothing was
written.` Warnings are printed and do not stop it. Fix every error, run it again, and repeat: a fix can reveal the
next one.

The messages below were produced by running `fleet` on a scratch flake with each mistake made on purpose. `<…>` is
what changes in your flake.

## Errors from `fleet`

| You see | What it means | Fix |
|---|---|---|
| `error: <a>: address 192.168.50.20 is used by <a>, <b>` | Two records (or a record and a device lease) have the same IP. | Give one a different `ip`. |
| `error: <a>: MAC 02:00:00:00:00:20 is used by <a>, <b>` | Two interfaces have the same MAC. Often a copied record. | Give the new one its own MAC. |
| `error: <a>: address 192.168.50.30 is used by <a>, device printer` | A hand-kept device lease clashes with a host. | Move the device or the host. |
| `error: <a>: interface lan: 192.168.77.21 is outside zone `lan` (192.168.50.0/24)` | The address is not in the zone's `subnet`. | Fix the `ip`, or the interface's `zone`. |
| `error: <a>: interface lan: unknown zone `dmz`` | The interface names a zone that is not in `network/zones.nix`. | Add the zone, or fix the name. |
| `error: <a>: interface lan: hv1 has no attachment for zone `dmz` (fmf.host.hypervisor.networks.dmz)` | A MicroVM is in a zone its hypervisor has not said how to reach. | In the hypervisor's `attachment.nix`: `fmf.host.hypervisor.networks.dmz.bridge = "<bridge>";` (or `macvtap`). |
| `error: <vm>: an active MicroVM needs placement.runsOn (a standby one may be unplaced)` | The VM does not say which hypervisor runs it. | Add `placement.runsOn = "<hypervisor>";`, or `lifecycle = "standby";` if it is not run anywhere. |
| `error: <a>: boot.after `<b>` runs on ``, not on `<hv>`: ordering across machines is not possible` | The VM it waits for is not placed on the same hypervisor (here it is not placed at all). | Place `<b>` on the same hypervisor, or remove the ordering. |
| `error: <a>: boot.after `hv1` is not a MicroVM (use boot.hostUnits for units on the hypervisor)` | `boot.after` can only name VMs. | To wait for a service on the hypervisor: `boot.hostUnits = ["some.service"];`. |
| `error: <a>: boot.after `<b>` is retired` / `refers to retired host `<b>`` | A record points at a host marked `retired`. | Remove the reference, or un-retire `<b>`. |
| `error: <b>: storage path /persist/vm-data/<a>/www is claimed by <b>, <a> and not marked shared` | Two VMs share one host folder. | Give them separate paths, or set `shared = true;` on the entries if sharing is deliberate. |
| `error: <h>: has 2 interfaces and none is marked primary` | A machine with several interfaces has to say which one its name resolves to. | `primary = true;` on one interface. |

`fleet` also reports, as errors, a boot-order cycle, two hosts claiming one Vault role, and a DNS name that would
resolve to two addresses. The last usually means a **host** called `vault` and a **service** called
`vault.<your domain>`: give each zone its own `hostDomain` so host names live under a different domain from service
names.

## Warnings from `fleet`

| You see | Meaning | What to do |
|---|---|---|
| `interface <n>: uses DHCP but has no MAC, so no lease can be generated for <ip>` | `static = false` with an `ip` but no `mac`. | Add the `mac`, or set `ip = null;`. |
| `interface <n>: static <ip> is inside the DHCP pool of `<zone>` and no lease reserves it (give the interface its MAC)` | DHCP may hand this address to someone else. | Add the `mac` so a lease reserves it, or move the address outside the pool. |
| `interface <n>: <mac> is not a locally administered MAC` | A made-up MAC should start `02:`, `06:`, `0a:`, `0e:` and so on (second hex digit 2, 6, a or e), which cannot clash with a real card. | Change the MAC if it was made up. |
| `<h>: has no network interface` | A record with no interfaces. | Add one, or leave it if the host is not on the network. |
| `expose is ignored while the host is standby` (or `retired`) | Port forwards only apply to an `active` host. | Expected. |
| `placement.runsOn is ignored on a physical host` | `runsOn` only means something for a MicroVM. | Delete the line. |
| `interface <n>: `<tap>` joins <bridge> on <hv> (first match: <rule>), but zone `<zone>` attaches to <bridge2>` | The tap lands on a different bridge from the one its zone says. | Fix whichever is wrong: the hypervisor's `attachment.nix` or its hand-written rule. |
| `interface <n>: no .network file on <hv> matches `<tap>`, so it joins no bridge` | Nothing puts that VM's tap on a bridge. **On the first run after you turn on `tapRules` this goes away when you run `fleet` a second time**, because the rule is read from the file `fleet` has just written. | Run `fleet` again. If it persists: turn on `hypervisor.tapRules`, or add a rule. |
| `interface <n>: <ip> is static in the record but the machine configures <other>` | The record and the machine's own configuration disagree. | Fix the one that is wrong. |

## Before `fleet` gets going

| You see | Why | Fix |
|---|---|---|
| `FAIL <host> (evaluation, 3 attempts)` and then `some hosts failed to evaluate; refusing to continue.` | One host's NixOS configuration does not evaluate, so `fleet` cannot read its record. | Run `nix eval .#nixosConfigurations.<host>.config.fmf.host.kind` to see the real error; it is almost always one of the next rows. |
| `The option `nixos-boot' does not exist` (or any other `The option … does not exist`) | The module list in `flake.nix` is missing a module fmf expects. | Use the full list in [Getting started](FLEET-GETTING-STARTED.md#step-1-wire-the-flake-once). |
| `The option `fmf.host' does not exist` | Your locked `fmf` is older than the host model. | `nix flake update fmf`. |
| `The option `microvm.hypervisor' does not exist` in a machine you meant to be a VM | The directory name does not start with `vm-`, so the VM module was not loaded. | Rename the directory to `vm-<name>`. |
| `The option `home-manager.users.admin.snowfallorg.user.name' was accessed but has no value defined` | fmf's user module needs it for the user it creates. | Add `home-manager.users.admin.snowfallorg.user.name = "admin";` (use your user's name). |
| `Failed assertions: `nix.optimise.automatic` and `nix.settings.auto-optimise-store` do not work with `microvm.writableStoreOverlay`.` | A VM with a writable store (`nixStore` `persistent` or `volatile`) cannot optimise its store. | In the VM: `nix.optimise.automatic = lib.mkForce false; nix.settings.auto-optimise-store = lib.mkForce false;`. |
| A file you just wrote seems to be ignored; `path … does not exist` | Nix only sees files git knows about. | `git add <file>`. |
| An error about a missing file under `network/generated/` | The generated files do not exist yet, and hosts import them. | Create the four empty placeholders ([Getting started, step 3](FLEET-GETTING-STARTED.md#step-3-create-the-empty-generated-files-and-the-hypervisor-reader)), `git add` them, run `fleet`. |
| `fleet` runs out of memory, or the machine swaps | It evaluates each host in a separate process, a few at a time. | `fleet --jobs 1`. |

## `fleet --check` and the drift check fail

`fleet --check` prints a diff; the Nix check prints `stale: network/generated/<file>`. Either means a record or a
device lease changed and `fleet` was not run. Run `fleet`, look at the diff, commit it together with the record.
If it says `missing: network/generated/<file>`, a file was never committed; run `fleet` and `git add` all four.

If it fails and you **did** run `fleet`, check that you ran it with the same `--device-leases` the check uses.

## Symptoms on a running machine

| Symptom | Likely cause | Check, then fix |
|---|---|---|
| I changed a record and nothing changed on the network | `fleet` is up to date but the machine that **reads** the file was not deployed. | Deploy the router and DNS server for `leases`, `dns`, `forwards`; the hypervisor for `microvms`. |
| A VM does not start after deploy | A directory it shares does not exist. Likely when the VM is `placement.hostDirectories = "external"`, a storage entry has `createDirectory = false`, or the root-password share is on and `/persist/system/secrets` is missing. | `journalctl -u microvm@vm-<name> -e`. Create the directory, or set `standardShares.rootPassword = false;`. To see what it shares: `nix eval --json .#nixosConfigurations.vm-<name>.config.microvm.shares`. |
| A VM runs but has no network | Its tap is not on a bridge: `tapRules` is off and no hand-written rule matches, or the tap's name differs from the record. | On the hypervisor: `bridge link` and `networkctl`. Compare the tap name with `fmf.host.network.interfaces.<n>.id` and the VM's `microvm.interfaces`. |
| A VM has no address | `network.derive` is off and the VM's own settings are missing, or the lease was not deployed to the router, or the MAC is not the VM's. | `nix eval --json .#nixosConfigurations.vm-<name>.config.systemd.network.networks`; compare `mac` in the record with `microvm.interfaces`. |
| A VM restarts at every deploy | Its definition changed, and `restartIfChanged` is true. | Expected for ordinary VMs. For a VM that must not restart (the Vault VM), leave `placement.restartIfChanged` **unset**. |
| A VM has no lease although I gave it an address | The interface has no `mac`. **`fleet` does not stop you**: a lease needs a MAC, and `network.derive` also needs one to name the link. | Add `mac = "02:00:00:00:00:XX";`. |
| Shares appear twice, or two copies of a share | The VM has `derive = true` **and** a hand-written `microvm.shares`. | Delete the hand-written list. |
| `microvm.vms.<vm>` is defined twice | The hypervisor still has a hand-written stanza for a VM that is now derived. | Delete the stanza from the hypervisor. |
| A new share (`ssh-host-keys`, `root-password`) appeared after converting a VM | The derived list always has the standard shares. | Expected. Create the directory if the VM is `external`, or switch the share off (`standardShares.rootPassword = false;`). |
| A VM's data looks empty after converting it | Its folder is now at a new default path (`/persist/vm-data/<vm>/<name>`). | Set `hostPath` to the old path, with `createDirectory = false;`, or move the data. |

## Still stuck

- `fleet --show <host>` prints the lease and DNS names for one machine, which separates "wrong record" from "wrong
  reader".
- `nix eval --json .#nixosConfigurations.<host>.config.fmf.host` prints the whole record as Nix sees it, defaults
  included.
- The list of options and their defaults is the [host record reference](../modules/nixos/system/host/README.md);
  the rules and the reasons for them are in [Host model](HOST-MODEL.md).

## What was verified

The `fleet` errors and warnings quoted in the first two tables, and the first-run tap warning, were produced by
running `fleet` in a scratch flake with the mistake introduced. The evaluation errors in the third table (the missing
module, the user-name option, the store-optimisation assertion, and a directory not named `vm-*`) were hit while building that flake. The symptoms table
is reasoning from how the files are consumed and from Campground's experience; those were not reproduced on real
machines. The old-lock `fmf.host` message is the expected Nix wording and
was not reproduced.
