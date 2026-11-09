---
type: Tutorial
title: MicroVMs from records
description: Describe a hypervisor and two MicroVMs with host records, let fleet derive the VM list, shared directories, start order and network rules, and bring the VMs up - written for someone who has not used the host model before.
tags: [fleet, hosts, tutorial, microvm, hypervisor, storage]
status: draft
---

# MicroVMs from records

By the end of this tutorial one hypervisor (`hv1`) runs two MicroVMs (`vm-db` and `vm-web`), and the only things
you wrote by hand are small records and the VMs' own services. Everything else the hypervisor needs is derived:

- the list of VMs it runs and whether each starts at boot,
- the directories it shares into each VM,
- the order VMs start in,
- which bridge each VM's network cable plugs into.

Do [Getting started](FLEET-GETTING-STARTED.md) first (the flake wiring, `zones.nix`, the reader module and the empty
generated files). This page uses the same example network: `192.168.50.0/24`, zone `lan`.

## What a MicroVM is, in this model

A MicroVM is a NixOS machine that does not boot from its own disk. A **hypervisor** (a real NixOS machine) starts
it, gives it a network cable (a *tap*), and shares folders into it. Normally you describe a VM in three places: in
the VM, in the hypervisor's `microvm.vms`, and in the hypervisor's directory-creation rules. The fleet lets you
describe it in one:

| You write | Where | It says |
|---|---|---|
| `default.nix` | the VM | What the VM **does**: its services, CPU, memory. |
| `host.nix` | the VM | Where it **is**: its address and MAC, and which hypervisor runs it. |
| `storage.nix` | the VM | What it **keeps**: the folders it needs and how its Nix store is stored. |
| `host.nix`, `attachment.nix` | the hypervisor | Its own address, and which bridge a VM in each zone plugs into. |

## Step 1: describe the hypervisor

`hv1` is an ordinary NixOS machine that you already have (keep its `hardware.nix`). Add three things.

**`systems/x86_64-linux/hv1/host.nix`**: what the machine is.

```nix
{...}: {
  fmf.host = {
    kind = "physical";
    network.interfaces.lan = {
      ip = "192.168.50.10";
      mac = "aa:bb:cc:00:00:10";
      static = true; # the machine sets this address itself (see default.nix)
      zone = "lan";
    };
  };
}
```

**`systems/x86_64-linux/hv1/attachment.nix`**: how a VM in each zone reaches the network.

```nix
{...}: {
  # A VM in the "lan" zone plugs into the bridge called br0 ...
  fmf.host.hypervisor.networks.lan.bridge = "br0";
  # ... and fleet writes the rule that does the plugging.
  fmf.host.hypervisor.tapRules = true;
}
```

**`systems/x86_64-linux/hv1/default.nix`**: the machine itself. The new parts are `microvm.host.enable` and the
bridge. If you already have a bridge, name it in `attachment.nix` and skip the bridge lines.

```nix
{...}: {
  imports = [./hardware.nix];

  home-manager.users.admin.snowfallorg.user.name = "admin";
  fmf.user = {
    name = "admin";
    fullName = "Admin";
    email = "admin@example.com";
    extraGroups = ["wheel"];
  };

  # This machine runs MicroVMs.
  microvm.host.enable = true;

  # A bridge (br0) that the real network card (eno1) and every VM's tap plug into.
  networking.useNetworkd = true;
  systemd.network.netdevs."20-br0".netdevConfig = {
    Kind = "bridge";
    Name = "br0";
  };
  systemd.network.networks."20-br0" = {
    matchConfig.Name = "br0";
    address = ["192.168.50.10/24"];
    gateway = ["192.168.50.1"];
  };
  systemd.network.networks."21-uplink" = {
    matchConfig.Name = "eno1";
    networkConfig.Bridge = "br0";
  };

  system.stateVersion = "25.11";
}
```

Replace `eno1` with the machine's real network interface. Do not deploy yet: a bridge that is set up wrongly can
cut you off from the machine, so deploy it last, from a console you can reach.

> `tapRules = true` makes `fleet` write one rule per VM tap. Without it the hypervisor needs its own hand-written
> rule that matches the VM taps (for example everything named `vm-*`) and puts them on the bridge. Do it one
> way or the other, not both.

## Step 2: write the first VM

Make the directory `systems/x86_64-linux/vm-db/`. A name that starts with `vm-` is what makes the flake treat it
as a MicroVM. Three files.

**`default.nix`**: what the VM does. This one runs a database.

```nix
{lib, ...}: {
  # A MicroVM is started by its hypervisor, so it has no boot loader.
  boot.loader.grub.enable = lib.mkForce false;
  boot.loader.systemd-boot.enable = lib.mkForce false;

  microvm = {
    hypervisor = "qemu";
    vcpu = 2;
    mem = 2047; # a little under 2 GiB: exactly 2048 trips a QEMU bug
    socket = "control.socket";
  };

  # The VM has a writable Nix store (see storage.nix), which does not work with store optimisation.
  nix.optimise.automatic = lib.mkForce false;
  nix.settings.auto-optimise-store = lib.mkForce false;

  # fmf's user module needs this for the user it creates.
  home-manager.users.admin.snowfallorg.user.name = "admin";

  fmf.user = {
    name = "admin";
    fullName = "Admin";
    email = "admin@example.com";
    extraGroups = ["wheel"];
  };

  services.postgresql.enable = true;

  system.stateVersion = "25.11";
}
```

Notice what is **not** here: no `microvm.shares`, no `writableStoreOverlay`, no `microvm.interfaces`, no network
address. Those come from the record. (If you write `microvm.shares` yourself in a VM that also says
`derive = true`, your entries are added to the derived ones. Delete the hand-written list when you convert.)

**`host.nix`**: where it is.

```nix
{...}: {
  fmf.host = {
    kind = "microvm";
    placement.runsOn = "hv1"; # the hypervisor's directory name
    network = {
      derive = true; # the VM configures its own network from this record
      interfaces.lan = {
        ip = "192.168.50.21";
        mac = "02:00:00:00:00:21";
        zone = "lan";
      };
    };
  };
}
```

| Field | Meaning |
|---|---|
| `placement.runsOn` | Which physical host runs this VM. Required for an active VM. |
| `network.derive = true` | The VM sets up its own network (a link named `lan0`, this address, the zone's gateway and DNS, no DHCP) and defines its tap. Without it, you write that in `default.nix` yourself. |
| `mac` | Pick `02:00:00:00:00:XX`. The leading `02` marks a locally chosen address, which cannot clash with a real card. Every VM needs its own. |
| `ip` | An address in the zone's subnet, outside the DHCP pool. |

To give the VM different name servers from its zone's (a DNS server uses public resolvers, or you want a fallback after
yours), set them in the record: `fmf.host.network.dns = ["192.168.50.1" "1.1.1.1"];`. Put them there rather than in the
VM's `networking.nameservers`.

**`storage.nix`**: what it keeps.

```nix
{...}: {
  fmf.host = {
    derive = true; # shares and store come from this record
    standardShares.rootPassword = false;
    storage.postgres.mountPoint = "/var/lib/postgresql";
  };
}
```

| Field | Meaning |
|---|---|
| `derive = true` | Take this VM's shares and store layout from the record, and have the hypervisor create the matching directories. Default is false, so you convert a VM deliberately. |
| `standardShares.rootPassword = false` | Skip the share that hands the hypervisor's `/persist/system/secrets` to the VM for its root password. You only want it if you use `fmf.system.passwds`. It is on by default, and the hypervisor never creates that directory, so leaving it on without creating the directory yourself leaves the VM with a share whose source does not exist. |
| `storage.postgres` | One folder to keep: it appears **inside** the VM at `mountPoint`, and on the hypervisor at `/persist/vm-data/vm-db/postgres`. The name (`postgres`) is also the share's label. |

`nixStore` is not set, so it is `"persistent"`: the VM gets a writable Nix store kept on the hypervisor at
`/persist/vm-stores/vm-db/nix-store`, so packages the VM installs survive a restart. The other choices are
`"volatile"` (writable, thrown away at each restart) and `"none"` (read-only store).

```bash
git add systems/x86_64-linux/hv1 systems/x86_64-linux/vm-db
```

## Step 3: run `fleet`

```bash
nix run --inputs-from . fmf#fleet
```

```
wrote network/generated/: 2 host leases, 6 DNS names, 0 port forwards, 1 generated MicroVMs (2 active hosts, 0 standby, 0 retired)
```

Open `network/generated/microvms.nix`:

```nix
{
  "hv1" = {
    vms = {
      "vm-db" = {autostart = true;};
    };
    tmpfiles = [
      "d /persist/vm-data/vm-db 0755 root root -"
      "d /persist/vm-data/vm-db/postgres 0755 root root -"
      "d /persist/vm-data/vm-db/ssh 0700 root root -"
      "d /persist/vm-stores/vm-db 0755 root root -"
      "d /persist/vm-stores/vm-db/nix-store 0755 root root -"
    ];
    units = {
    };
    tapRules = [
      {name = "vm-db"; bridge = "br0";}
    ];
  };
}
```

This is what the hypervisor will do, keyed by the hypervisor's name:

| Part | What the hypervisor does with it |
|---|---|
| `vms` | Becomes `microvm.vms`: run `vm-db`, start it at boot. The reader module adds `flake = inputs.self`. |
| `tmpfiles` | Creates these directories at boot (`d` rules). |
| `units` | Start-order rules. Empty so far. |
| `tapRules` | Plugs the VM's tap into `br0`. |

You never edit this file. Change a record and run `fleet` again.

## Step 4: see what the VM will get

Before deploying, ask Nix what it computed. These commands change nothing.

```bash
# The folders shared into the VM, in order
nix eval --json .#nixosConfigurations.vm-db.config.microvm.shares \
  --apply 'l: map (s: s.tag + "  " + s.source + "  ->  " + s.mountPoint) l'
```

For `vm-db` that is (the command prints a JSON list; it is laid out in columns here):

```
ro-store        /nix/store                                 ->  /nix/.ro-store
rw-store        /persist/vm-stores/vm-db/nix-store         ->  /nix/.rw-store
ssh-host-keys   /persist/vm-data/vm-db/ssh                 ->  /persist/ssh
postgres        /persist/vm-data/vm-db/postgres            ->  /var/lib/postgresql
```

The first three are **standard shares** every derived VM gets, in this order: the host's Nix store (read-only), the
VM's writable store, and a folder for SSH host keys. A `vault-agent` share is added when the VM runs
`fmf.services.vault-agent`, and `root-password` unless you turned it off. Then come your own `storage` entries.

```bash
# The VM's own network
nix eval --json .#nixosConfigurations.vm-db.config.systemd.network.networks.\"20-lan0\" \
  --apply 'n: { inherit (n) address gateway; }'
```

```
{"address":["192.168.50.21/24"],"gateway":["192.168.50.1"]}
```

## Step 5: add a second VM that starts after the first

Say the web server needs the database up first. Create `vm-web` with the same three files, changed like this:

```nix
# systems/x86_64-linux/vm-web/host.nix
{...}: {
  fmf.host = {
    kind = "microvm";
    placement.runsOn = "hv1";
    boot.after = ["vm-db"]; # start after vm-db (a VM on the SAME hypervisor)
    network = {
      derive = true;
      interfaces.lan = {
        ip = "192.168.50.20";
        mac = "02:00:00:00:00:20";
        zone = "lan";
      };
    };
    expose = [
      {
        port = 443;
        description = "HTTPS to the web VM";
      }
    ];
  };
}
```

```nix
# systems/x86_64-linux/vm-web/storage.nix
{...}: {
  fmf.host = {
    derive = true;
    standardShares.rootPassword = false;
    storage.www.mountPoint = "/var/www";
  };
}
```

`default.nix` is the same as `vm-db`'s with `services.nginx.enable = true;` and
`networking.firewall.allowedTCPPorts = [80 443];` in place of PostgreSQL.

- **`boot.after`** lists VMs on the **same** hypervisor. `fleet` turns it into a systemd ordering rule. A VM on
  another machine is an error: nothing can wait for a machine across the network. To wait for a service on the
  hypervisor itself, use `boot.hostUnits = ["some.service"];`.
- **`expose`** opens a port on the router and forwards it to this VM. It is the networking half; see [the
  networking tutorial](FLEET-TUTORIAL-NETWORK.md). If you have no router consumer, `expose` simply sits in
  `forwards.nix`, unused.

Run `git add systems/x86_64-linux/vm-web` and `fleet` again. `microvms.nix` now has both VMs and:

```nix
    units = {
      "microvm@vm-web" = {after = ["microvm@vm-db.service"]; wants = ["microvm@vm-db.service"];};
    };
    tapRules = [
      {name = "vm-db"; bridge = "br0";}
      {name = "vm-web"; bridge = "br0";}
    ];
```

## Step 6: check, commit, deploy

```bash
nix run --inputs-from . fmf#fleet -- --check   # "fleet: up to date"
git add -A && git commit -m "hv1 runs vm-db and vm-web"
```

Deploy the **hypervisor**, which is the machine that changed. The VMs are built by the hypervisor from your
flake:

```bash
nixos-rebuild switch --flake .#hv1 --target-host admin@192.168.50.10
```

Then, on the hypervisor:

```bash
systemctl status microvm@vm-db microvm@vm-web
ls /persist/vm-data/vm-db            # postgres  ssh
journalctl -u microvm@vm-db -e       # if a VM did not come up
sudo systemctl start microvm@vm-db   # only if it did not start by itself
```

From another machine, `ping 192.168.50.21` should answer once `vm-db` is up.

## If the VM uses Vault

A VM that enables `fmf.services.vault-agent` gets one more share automatically, the directory that holds its
credentials: `/persist/system/var/lib/vault/<vm>` on the hypervisor, mounted at `/var/lib/vault/<vm>` in the VM.
The hypervisor creates the **directory** (mode 0700) but not the **files**. You copy the VM's `role-id` and
`secret-id` into it by hand; they never go in Nix. See the [Vault runbook](VAULT-RUNBOOK.md) ("Add a host").
Add `boot.after = ["vm-vault"]` to a VM that reads secrets and runs on the same hypervisor as the Vault VM.

## Two deliberate choices

- **Restarting on deploy.** A VM restarts when its definition changes and the hypervisor is deployed, unless
  `placement.restartIfChanged` says otherwise. Leave it **unset** for a VM that must never restart by itself
  (the Vault VM: restarting it seals Vault). Unset means "the default for a flake-based VM", which is not to
  restart. Set `restartIfChanged = true;` for an ordinary VM that should pick up changes at each deploy.
- **`placement.hostDirectories`.** By default the hypervisor creates the VM's directories. If the directories
  already exist and hold data, the generated rule would reset their owner and mode. Set
  `placement.hostDirectories = "external"` to stop generating them. The
  [runbook](FLEET-RUNBOOK.md#convert-an-existing-hand-written-vm) covers converting a VM that already runs.

## Where to go from here

- Several hypervisors, a VM that has two networks, a macvtap setup: [examples](FLEET-EXAMPLES.md).
- Moving a VM, retiring one, converting one that already runs: [runbook](FLEET-RUNBOOK.md).
- The router, DHCP and DNS half of the story: [networking tutorial](FLEET-TUTORIAL-NETWORK.md).
- Every option: [host record reference](../modules/nixos/system/host/README.md).

## What was and was not tested

The files above were run in a scratch downstream flake: `fleet` wrote the output shown (the `vm-db` extracts are
from a run with both VMs, trimmed to one), the hypervisor and both VMs evaluated, and the share, tap rule and
network values were read back with `nix eval`. **Not done:** deploying `hv1`, booting a VM, and a whole-system
`nix build` (it was blocked in this checkout by an unrelated stale `oisd` input in fmf's lock).
