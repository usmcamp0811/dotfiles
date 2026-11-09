---
type: Runbook
title: Fleet runbook - day-to-day operations
description: Step-by-step procedures for a flake that uses fmf.host records and fleet - the daily loop, adding a host or MicroVM, changing an address, exposing a port, moving, retiring and converting a VM, generated tap rules, a CI drift check, upgrading fmf and rolling back.
tags: [fleet, hosts, runbook, operations, microvm, network]
status: draft
---

# Fleet runbook

How to do the common jobs once the flake is wired up. If you have not wired it yet, start with
[Getting started](FLEET-GETTING-STARTED.md). If a command fails, look it up in
[troubleshooting](FLEET-TROUBLESHOOTING.md).

All commands run from the root of your flake. `fleet` below means:

```bash
nix run --inputs-from . fmf#fleet --
```

so `fleet --check` is `nix run --inputs-from . fmf#fleet -- --check`. If your device lease files are not in
fmf's default location, add `--device-leases 'your/path/*-leases.nix'` to every call (see
[the networking tutorial](FLEET-TUTORIAL-NETWORK.md#step-2-machines-that-are-not-nixos)).

## The daily loop

Every change to the fleet is the same five steps:

1. **Edit** the machine's record (`host.nix`, `storage.nix` or `attachment.nix`), then `git add` any new file.
2. **Run `fleet`.** It refuses to write while there are errors and tells you which record to fix.
3. **Look at the diff** of `network/generated/`. That diff is exactly what changes on your network. If it is
   bigger than you expected, stop and find out why.
4. **Commit the record and the generated files together.** One without the other makes a stale tree.
5. **Deploy the machines that read the files:** the router and DNS server for `leases`, `dns` and `forwards`; the
   hypervisor for `microvms`. The machines you described need a deploy only if their own `default.nix`
   changed or the record changes how they configure themselves (`network.derive`, `storage.nix`).

```bash
fleet                       # write
git diff network/generated  # review
fleet --check               # "fleet: up to date"
git add -A && git commit
```

Three rules:

- **Never edit `network/generated/`.** A hand edit is overwritten on the next run, and the drift check fails.
- **Never put a host in a hand-kept lease file.** Those are for machines that have no record. A machine in both
  places is reported as a clash.
- **Commit a record and its generated files in the same commit.**

## Add a physical host

1. Create `systems/x86_64-linux/<name>/` with `default.nix` as usual.
2. Write `host.nix`:

   ```nix
   {...}: {
     fmf.host = {
       kind = "physical";
       network.interfaces.lan = {
         ip = "192.168.50.40";
         mac = "aa:bb:cc:00:00:40";
         zone = "lan";
       };
     };
   }
   ```

   Use `ip = null` for a machine that takes whatever DHCP gives it. Add `static = true;` if the machine sets its
   own address and does not use DHCP.
3. `git add`, `fleet`, review, commit.
4. Deploy the router and DNS server. The new machine can now be given its address by DHCP and resolved by name.

## Add a MicroVM

1. Pick a free `ip` in the zone (outside the DHCP pool) and a unique MAC `02:00:00:00:00:XX`. `fleet` rejects a
   duplicate of either.
2. Create `systems/x86_64-linux/vm-<name>/` with three files. `default.nix` has the boot loaders off, `microvm.hypervisor`,
   `vcpu`, `mem` and the VM's services, and **no** shares and **no** network settings. Copy the
   [VM tutorial's](FLEET-TUTORIAL-VMS.md#step-2-write-the-first-vm) files:
   - `host.nix`: `kind = "microvm"`, `placement.runsOn`, `network.derive = true`, the interface; `boot.after = ["vm-vault"]`
     if it reads secrets through vault-agent on the same hypervisor as the Vault VM.
   - `storage.nix`: `derive = true`, `standardShares.rootPassword = false` unless you use `fmf.system.passwds`,
     and one `storage.<name>.mountPoint` for each folder the VM keeps.
3. `git add` the directory, run `fleet`, review `microvms.nix` (the hypervisor gains the VM, its directories and
   its tap rule), commit.
4. If the VM uses vault-agent, create the Vault role and copy `role-id` and `secret-id` into
   `/persist/system/var/lib/vault/vm-<name>/` on the **hypervisor** (see the
   [Vault runbook](VAULT-RUNBOOK.md), "Add a host"). The hypervisor creates the directory, not the files.
5. Deploy the hypervisor, then start the VM if it did not start itself:

   ```bash
   nixos-rebuild switch --flake .#<hypervisor> --target-host admin@<hypervisor-ip>
   ssh admin@<hypervisor-ip> sudo systemctl start microvm@vm-<name>
   ```
6. Deploy the router and DNS server so the VM's lease, name and any forwards exist there.

## Change an address or MAC

Edit `ip` or `mac` in the record. `fleet` regenerates the lease and the names and rejects a clash. Then:

| What you changed | Also do |
|---|---|
| A physical host with `static = false` | Deploy the router. The machine picks up the new address when its lease renews or it reboots. |
| A host with `static = true`, or a MicroVM with `network.derive` | Deploy **that machine** too: it sets its own address from the record. Deploy it **and** the router in one sitting. |
| A MicroVM's `mac` | Deploy the hypervisor and the VM; the tap is recreated with the new MAC. |
| The gateway or a DHCP server's own address | Do it from a console that does not depend on the old address. |

A static address that is inside the DHCP pool is a warning, not an error: the lease generated for a host with a MAC
covers it, but a static host without a MAC leaves that address free for DHCP to give away. Give the interface its MAC.

## Open or close a port

Edit `fmf.host.expose` on the machine that receives the traffic (see
[the networking tutorial](FLEET-TUTORIAL-NETWORK.md#step-5-expose-a-port)). Run `fleet`, commit, deploy the **router**.
Removing the entry removes the forward. Setting the host `standby` or `retired` also stops forwarding to it (with a
warning).

## Add or change a device (a machine with no record)

Edit your device lease file (for example `network/devices/lan-leases.nix`; the file name is the zone). Run `fleet`
so DNS and the clash check include it, commit, deploy the router and DNS server.

## Add a network zone or VLAN

1. Add it to `network/zones.nix` (subnet, gateway, dns, `dhcpRange`, `hostDomain`, and `vlanId` for a VLAN).
2. Create the VLAN on the router with whatever your router module uses; the zone catalogue does not configure the
   router for you.
3. Point interfaces at it with `zone = "<id>"`.
4. On a hypervisor that runs VMs in the new zone, say how they reach it in `attachment.nix`:
   `fmf.host.hypervisor.networks.<zone>.bridge = "<bridge>";` A VM in a zone the hypervisor has no entry for is an
   error: `<hypervisor> has no attachment for zone ...`.

A tap interface can only join a **bridge**. A VLAN interface (such as `br-lan.10`, which carries the router's gateway
address for that VLAN) is not a bridge; `fleet` reports pointing a zone at one.

## Park a VM (standby) and bring it back

Parking keeps the VM's name and address reserved without starting it:

```nix
fmf.host.lifecycle = "standby";   # in host.nix; you can also delete placement.runsOn
```

Standby VMs get a lease and DNS names, no port forwards, no autostart, and nothing on a hypervisor. To bring one
back, delete the `lifecycle` line, make sure `placement.runsOn` and `storage.nix` (`derive = true`) are there, run
`fleet`, and deploy the hypervisor.

## Move a MicroVM to another hypervisor

Only the VM's **record** says where it runs, but its **data** lives on the hypervisor, so you have to move it.

1. Make sure the new hypervisor has `attachment.nix` with the VM's zone, and `microvm.host.enable = true`.
2. **Stop the VM on the old hypervisor** (`sudo systemctl stop microvm@vm-<name>`). Two copies with the same MAC
   on one network break both.
3. Copy the VM's data to the same paths on the new hypervisor: `/persist/vm-data/vm-<name>`,
   `/persist/vm-stores/vm-<name>`, and `/persist/system/var/lib/vault/vm-<name>` if it uses vault-agent.
   (`rsync -aHAX --numeric-ids` keeps owners.)
4. Change `placement.runsOn`, run `fleet`, commit.
5. Deploy the **old** hypervisor (it drops the VM), then the **new** one, then start the VM there.
6. If the VM's address is static in the record, nothing else changes; the router needs no deploy unless a port
   forward's destination changed.

## Retire a host

```nix
fmf.host = {
  kind = "microvm";
  lifecycle = "retired";
  retired = {
    since = "2026-11-09";
    reason = "replaced by vm-web2";
    replacedBy = "vm-web2";
  };
};
```

A retired host generates **nothing**: no lease, no DNS, no forward, nothing on a hypervisor. Leave its directory in
`systems/` (it must still evaluate), or delete the directory when you want it gone completely. Any other record
that still refers to it (`boot.after`, `placement.runsOn`) becomes an error, so `fleet` finds what you forgot.
Deploy the router, DNS server and hypervisor. If it had a Vault role, `fleet`'s Vault output lists it for
deletion; see the [Vault runbook](VAULT-RUNBOOK.md).

## Convert an existing hand-written VM

Use this when a VM already runs with hand-written `microvm.shares`, a `microvm.vms.<vm>` stanza and `tmpfiles` rules
on its hypervisor, and you want it derived. Do one VM at a time. The goal is that **nothing changes except where it
is written**.

1. **Save what it is today.** Run these before you touch anything:

   ```bash
   nix eval --json .#nixosConfigurations.vm-x.config.microvm.shares \
     --apply 'l: map (s: {inherit (s) tag source mountPoint;}) l' > /tmp/before-shares.json
   nix eval --json .#nixosConfigurations.vm-x.config.microvm.writableStoreOverlay > /tmp/before-overlay.json
   nix eval --json .#nixosConfigurations.<hypervisor>.config.systemd.tmpfiles.rules > /tmp/before-tmpfiles.json
   ```

2. **Write `host.nix`** from what exists: the MAC from its `microvm.interfaces`, the address from its lease (or its
   own network settings), `static = false` if it uses DHCP, `placement.runsOn`, and `restartIfChanged` copied from the
   hypervisor's stanza. Leave `restartIfChanged` **unset** for a VM that must never restart on deploy.
3. **Write `storage.nix`** to match the old shares:

   | The old VM had | Write |
   |---|---|
   | An `rw-store` share and `writableStoreOverlay` | `nixStore = "persistent";` |
   | `writableStoreOverlay` and no `rw-store` share | `nixStore = "volatile";` |
   | No overlay | `nixStore = "none";` |
   | No `root-password` share | `standardShares.rootPassword = false;` |
   | Every other share | `storage.<name> = { mountPoint = "<where it appears>"; hostPath = "<its old source>"; };`, and `tag = "<old tag>";` if it differs |
   | A host folder that already exists and holds data | add `createDirectory = false;` so no rule resets its owner and mode |

   If **all** the VM's directories already exist, add `placement.hostDirectories = "external";` so none are
   generated. Then you must create these by hand, because the derived list always has them:
   `/persist/vm-data/<vm>/ssh` (the `ssh-host-keys` share) and, when the VM runs vault-agent,
   `/persist/system/var/lib/vault/<vm>`. The `root-password` share's directory, `/persist/system/secrets`, is never
   generated.
4. **Delete** the hand-written `microvm.shares` and `writableStoreOverlay` from the VM's `default.nix`, and the VM's
   `microvm.vms.<vm>` stanza, its VM-specific `tmpfiles` rules and its `microvm@<vm>` ordering from the hypervisor.
   (Both the old and the generated stanza defining the same VM is a conflict.)
5. `git add`, `fleet`, then **compare**:

   ```bash
   nix eval --json .#nixosConfigurations.vm-x.config.microvm.shares \
     --apply 'l: map (s: {inherit (s) tag source mountPoint;}) l' > /tmp/after-shares.json
   diff <(jq -S 'sort_by(.tag)' /tmp/before-shares.json) <(jq -S 'sort_by(.tag)' /tmp/after-shares.json)
   ```

   The two lists must be the same set. The one expected difference is a **new** standard share (usually
   `ssh-host-keys`) if the old VM had none. Order is not preserved: the model fixes one order, and it does not
   matter inside the guest.
6. **Deploy the hypervisor.** Changing a VM's shares changes its runner, so the VM **restarts** at this deploy
   unless `restartIfChanged` is false. Do it in a quiet moment and watch `journalctl -u microvm@vm-x -f`.
7. Check the services inside the VM, then convert the next one.

The comparison in step 5 is the gate Campground used for its VMs (shares equal as a set, before and after); it is what caught shares at non-standard
paths, which were moved to the standard path first, one at a time. The commands in this section were not run end to end for this page.

## Turn on generated tap rules

By default a hypervisor puts VM taps on its bridge with a rule you wrote (for example "everything named `vm-*` joins
`br0`"). `fleet` can write one rule per VM instead. Once you delete the hand-written rule, a VM placed on that
hypervisor that has not been converted (`derive = false`) gets no bridge, so convert every VM there first. A typo in
a tap name is then caught by `fleet` instead of silently leaving a VM off the network.

1. In the hypervisor's `attachment.nix`: `fmf.host.hypervisor.networks.<zone>.bridge = "<bridge>";` for each zone,
   and `fmf.host.hypervisor.tapRules = true;`.
2. If the VM's tap is not named like the host (15 characters at most), say so in the VM's `attachment.nix`:
   `fmf.host.network.interfaces.<name>.id = "<tap name>";`. It must match `microvm.interfaces.*.id` in the VM.
3. `fleet` writes `tapRules` for the hypervisor into `microvms.nix`; the reader module turns each into a
   `28-<tap>` rule. Delete the hand-written glob.
4. `fleet` warns if a tap would join a different bridge from the one the zone says.

Leave a router host hand-wired if its bridges are built by the router module (see
[the Host model notes](HOST-MODEL.md)); a router's VLAN interfaces are not bridges.
On a hypervisor that attaches a zone with macvtap rather than a bridge, no rule is generated.

## Add a drift check to CI

`fleet --check` compares the committed files with what the records imply. To make `nix flake check` fail when
someone edits a record and forgets to run `fleet`, add a check. With snowfall, this file is picked up
automatically as `checks.x86_64-linux.fleet`:

```nix
# checks/fleet/default.nix
{
  pkgs,
  inputs,
  lib,
  ...
}: let
  fl = (import "${inputs.fmf}/lib/fleet/default.nix" {lib = pkgs.lib;}).fleet;
  hosts = inputs.self.nixosConfigurations;
  r = fl.mk {
    hosts = lib.mapAttrs (n: h: fl.extract n h.config) hosts;
    zones = (lib.head (lib.attrValues hosts)).config.fmf.network.zones;
    deviceLeases = [];
  };
  files = fl.render r;
  committed = "${inputs.self}/network/generated";
  problems = pkgs.writeText "fleet-errors" (lib.concatMapStrings (e: "${e.host}: ${e.message}\n") r.errors);
in
  pkgs.runCommand "fleet-check" {} ''
    rc=0
    if [ -s ${problems} ]; then
      echo "the fleet has errors:" >&2
      sed 's/^/  /' ${problems} >&2
      rc=1
    fi
    cmp -s ${pkgs.writeText "leases.nix" files.leases} ${committed}/leases.nix || { echo "stale: network/generated/leases.nix" >&2; rc=1; }
    cmp -s ${pkgs.writeText "dns.nix" files.dns} ${committed}/dns.nix || { echo "stale: network/generated/dns.nix" >&2; rc=1; }
    cmp -s ${pkgs.writeText "forwards.nix" files.forwards} ${committed}/forwards.nix || { echo "stale: network/generated/forwards.nix" >&2; rc=1; }
    cmp -s ${pkgs.writeText "microvms.nix" files.microvms} ${committed}/microvms.nix || { echo "stale: network/generated/microvms.nix" >&2; rc=1; }
    if [ "$rc" -ne 0 ]; then
      echo "Run \`fleet\` and commit the result." >&2
      exit 1
    fi
    echo "fleet: up to date" | tee $out
  ''
```

If you keep device leases in files, read them into `deviceLeases` (the zone is the file name), as Campground's
`checks/fleet/default.nix` does:

```nix
  devicesDir = "${inputs.self}/network/devices";
  deviceFiles = lib.filter (n: lib.hasSuffix "-leases.nix" n) (builtins.attrNames (builtins.readDir devicesDir));
  deviceLeases = lib.concatMap (n: map (l: l // {zone = lib.removeSuffix "-leases.nix" n;}) (import "${devicesDir}/${n}")) deviceFiles;
```

and write `inherit deviceLeases;` in place of `deviceLeases = [];`. Run it with:

```bash
nix build .#checks.x86_64-linux.fleet
```

It evaluates every host, so it needs the same memory as `fleet`. When it fails it prints which file is stale; the
fix is always `fleet` and a commit.

## Update fmf

```bash
nix flake update fmf
fleet
git diff network/generated      # should normally be empty
```

An empty diff means the new fmf derives the same thing. A non-empty diff is a change in fmf's rules; read it
before committing. Read the fmf [update log](log.md) for what changed.

## Roll back

A bad record is undone like any commit: `git revert <commit>` (it contains the record **and** the generated files),
then deploy the same machines you deployed before. A machine that misbehaves right after a deploy can be put back
to its previous system without touching the flake:

```bash
ssh admin@<machine> sudo nixos-rebuild switch --rollback
```

A hypervisor that loses a VM stanza stops managing that VM; the VM's data directories stay on disk.

## Checklist for a quiet fleet

- `fleet --check` passes (or the drift check is in CI).
- No hand-written `microvm.shares` in a VM that says `derive = true`.
- No `vm-*` glob and `tapRules = true` on the same hypervisor.
- Every `restartIfChanged` is deliberate; the Vault VM leaves it unset.
- No host appears in a hand-kept lease file.
