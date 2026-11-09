---
type: Tutorial
title: Getting started with the fleet (fmf.host records and fleet)
description: A first-time walk-through for a downstream flake - what a host record is, the one-time flake wiring, your first record, running fleet, and which of the two follow-on tutorials (MicroVMs, networking, or both) to read next.
tags: [fleet, hosts, tutorial, getting-started, microvm, network]
status: draft
---

# Getting started with the fleet

This page takes you from "I have a flake that uses fmf" to "I have one machine described in a record and
`fleet` has generated files from it". It assumes you have never used the host model. You do not need to
understand how it works inside; you need to be able to edit `.nix` files and run commands.

When you finish this page, read **one or both** of the next tutorials:

- [MicroVMs from records](FLEET-TUTORIAL-VMS.md): describe virtual machines once and let the hypervisor derive
  everything it needs to run them.
- [Leases, DNS and port forwards from records](FLEET-TUTORIAL-NETWORK.md): describe machines once and let the
  router and DNS server derive their tables.

Everything that needs a command or a decision after that is in the [runbook](FLEET-RUNBOOK.md); copy-paste
snippets are in the [examples](FLEET-EXAMPLES.md); if something fails, see
[troubleshooting](FLEET-TROUBLESHOOTING.md). The design and the reasons behind it are in
[Host model](HOST-MODEL.md).

## The idea in one minute

Without the fleet, one machine is described in several unrelated places. A virtual machine's MAC address is
written in the VM, again in the router's DHCP list, and its IP appears in the DNS server and the port-forward
list. Its data directory is written on the hypervisor and again in the VM. When one copy changes and another does
not, things break quietly.

With the fleet, each machine has **one small file, its record** (`host.nix`), next to its `default.nix`. You
write the MAC, the IP, the zone and where it runs **once**. A command called **`fleet`** reads every record
and writes the tables the other machines need. The tables are ordinary `.nix` files that you commit.

```
  systems/web/host.nix  ─┐
  systems/db/host.nix   ─┼──►  fleet  ──►  network/generated/  ──►  router, DNS server, hypervisor
  systems/nas/host.nix  ─┘                 leases.nix  dns.nix  forwards.nix  microvms.nix
```

`fleet` also checks your work. Two machines with the same IP or MAC, an address outside its network, a
VM that starts after something on another machine: it refuses to write anything and tells you which record is
wrong.

## Words used in these pages

| Word | Meaning |
|---|---|
| **Record** | `systems/x86_64-linux/<name>/host.nix`. Says what the machine is and where it sits on the network. Setting it changes nothing on that machine by itself. |
| **Zone** | A network, such as "lan" (`192.168.50.0/24`). Defined once; a record names the zone its interface is in. |
| **Physical host** | A real machine (`kind = "physical"`). |
| **MicroVM** | A small virtual machine run by a physical host (`kind = "microvm"`). Its name starts with `vm-` by convention. |
| **Hypervisor** | The physical host that runs MicroVMs. A MicroVM's record says `placement.runsOn = "<hypervisor>"`. |
| **Lease** | A DHCP reservation: "this MAC always gets this IP". |
| **Generated files** | `network/generated/*.nix`, written by `fleet`. You commit them and never edit them by hand. |
| **Derive** | To compute something from the record instead of writing it twice. `derive = true` on a VM means its shares are computed from its record. |
| **Standby** | A VM that exists in the flake but is not run anywhere. It keeps its name and address reserved. |

## Choose your path

You can adopt as much or as little as you want. Both paths use the same records and the same one-time setup below.

| You want | You write | `fleet` generates | You read |
|---|---|---|---|
| **MicroVMs only** | A record and `storage.nix` per VM; a record and `attachment.nix` for the hypervisor | `microvms.nix`: the hypervisor's VM list, directories, start order and tap rules | [MicroVMs from records](FLEET-TUTORIAL-VMS.md) |
| **Networking only** | A record per machine you want in DHCP, DNS or port forwards | `leases.nix`, `dns.nix`, `forwards.nix` | [Leases, DNS and port forwards](FLEET-TUTORIAL-NETWORK.md) |
| **Both** | Both of the above | All four files | Both tutorials, VMs first |

`fleet` always writes all four files. A file you do not use is harmless; it just sits there.

## Before you start

You need:

1. **A flake built on [snowfall-lib](https://github.com/snowfallorg/lib) that already uses fmf.** That means a
   `flake.nix` with `fmf` as an input, and `systems/x86_64-linux/<name>/default.nix` for each machine. The
   [`example-downstream-flake` template](../templates/example-downstream-flake/flake.nix) and the Campground
   repository are examples. (A flake that is not built on snowfall is not covered here.)
2. **Git, with your flake in a repository.** Nix only sees files that git knows about. After you create a new
   file, run `git add <file>`; otherwise Nix behaves as if it did not exist.
3. **An fmf revision that has the host model.** If the `fmf` input is an old one, update it:

   ```bash
   nix flake update fmf
   ```

4. Enough memory. `fleet` evaluates every host in your flake once, about ten seconds and half a gigabyte each. It
   runs two at a time by default (`--jobs N` changes that), so a large fleet is slow, not impossible.

## Step 1: wire the flake (once)

Three things have to be added to `flake.nix`: the module list (so the `fmf.host` option exists), your zones and
the hypervisor reader, and a loop that loads each machine's record files. Nothing here changes a machine until
you add a record.

This is a complete `flake.nix`. If you already have one, keep your own inputs and settings and add only what is
marked **new**.

```nix
{
  description = "My downstream flake (uses fmf)";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/release-26.05";
    fmf.url = "git+https://gitlab.com/usmcamp0811/dotfiles.git?ref=nixos";
    snowfall-lib.url = "github:snowfallorg/lib";
    snowfall-lib.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager/release-26.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs: let
    fmfInputs = inputs.fmf.inputs or {};

    lib = inputs.snowfall-lib.mkLib {
      inherit inputs;
      src = ./.;
      snowfall = {
        meta = {
          name = "mine";
          title = "My Nix Config";
        };
        namespace = "mine";
      };
    };
  in
    lib.mkFlake {
      channels-config.allowUnfree = true;

      overlays = builtins.attrValues (inputs.fmf.overlays or {});
      homes.modules = builtins.attrValues (inputs.fmf.homeModules or {});

      systems.modules.nixos =
        [
          inputs.home-manager.nixosModules.home-manager
          fmfInputs.nixtheplanet.nixosModules.macos-ventura
          fmfInputs.vault-service.nixosModules.nixos-vault-service
          fmfInputs.nix-topology.nixosModules.default
          fmfInputs.catppuccin.nixosModules.catppuccin
          fmfInputs.flakeforge.nixosModules.flakeforge
          fmfInputs.funkwhale.nixosModules.default
          fmfInputs.authentik-nix.nixosModules.default
          fmfInputs.nixos-router.nixosModules.default
          fmfInputs.impermanence.nixosModules.impermanence
          fmfInputs.microvm.nixosModules.host
          fmfInputs.stylix.nixosModules.stylix
          fmfInputs.nixos-boot.nixosModules.default
        ]
        ++ (lib.attrValues fmfInputs.crystal-forge.nixosModules)
        # All of fmf's own modules. This is what provides the `fmf.host` option.
        ++ (lib.attrValues inputs.fmf.nixosModules)
        # new: your zones, and what a hypervisor reads from the generated files
        ++ [
          ./network/zones.nix
          ./network/microvm-host.nix
        ];

      # new: for every machine, also load its record files if it has them. A name that starts with
      # "vm-" also gets the MicroVM guest module.
      systems.hosts = let
        hostDir = ./systems/x86_64-linux;
        hostNames = builtins.attrNames (lib.filterAttrs (_: type: type == "directory") (builtins.readDir hostDir));
        record = name:
          builtins.filter builtins.pathExists [
            (hostDir + "/${name}/host.nix")
            (hostDir + "/${name}/storage.nix")
            (hostDir + "/${name}/attachment.nix")
          ];
      in
        lib.genAttrs hostNames (name: {
          modules =
            lib.optional (lib.hasPrefix "vm-" name) fmfInputs.microvm.nixosModules.microvm
            ++ record name;
        });
    };
}
```

What the **new** parts do:

- **The long module list** is the stack fmf's own modules expect. Leaving one out fails evaluation with
  `The option ... does not exist`, even for a feature you do not use. It is the same list as the
  [example template](../templates/example-downstream-flake/flake.nix) plus `stylix` and `nixos-boot`.
- **`./network/zones.nix`** is where you list your networks (next step).
- **`./network/microvm-host.nix`** is a small module every machine loads. On a hypervisor it reads
  `network/generated/microvms.nix`; everywhere else it does nothing.
- **`systems.hosts`** loads `host.nix`, `storage.nix` and `attachment.nix` from a machine's directory **if they
  exist**, so you add records one machine at a time. A directory whose name starts with `vm-` is treated as a
  MicroVM.

Commit nothing yet; the files these lines point at do not exist.

## Step 2: describe your networks (once)

Create `network/zones.nix`. A zone is a network the fleet knows about. Start with the one you have:

```nix
# network/zones.nix
{...}: {
  fmf.network.zones.lan = {
    description = "The main network";
    subnet = "192.168.50.0/24";
    gateway = "192.168.50.1";
    dns = ["192.168.50.1"];
    dhcpRange = {
      start = "192.168.50.100";
      end = "192.168.50.200";
    };
    hostDomain = "lan-hosts.example.com";
  };
}
```

Replace the addresses with your own. What each line is for:

| Line | Used for |
|---|---|
| `subnet` | Every interface's `ip` must be inside it, or `fleet` reports an error. |
| `gateway`, `dns` | Handed to a MicroVM that configures its own network (see [the VM tutorial](FLEET-TUTORIAL-VMS.md)). |
| `dhcpRange` | A static address inside the pool that nothing reserves produces a warning, so you do not hand out the same address twice. |
| `hostDomain` | Host names also resolve as `<name>.<hostDomain>`. Keep it **different** from the domain your services use, so a machine called `vault` does not clash with the service `vault.<your domain>`. |

Add more zones the same way (a VLAN has `vlanId = 10;`). Every interface in a record names a zone, so a zone must
exist before a machine can use it.

## Step 3: create the empty generated files and the hypervisor reader

`fleet` evaluates your hosts to write its files, and your hosts import those files. So they have to exist
first, empty:

```bash
mkdir -p network/generated
echo '{}' > network/generated/leases.nix
echo '{}' > network/generated/dns.nix
echo '[]' > network/generated/forwards.nix
echo '{}' > network/generated/microvms.nix
```

Create `network/microvm-host.nix`. You paste it in once and do not change it:

```nix
# network/microvm-host.nix
{
  config,
  lib,
  inputs,
  ...
}: let
  # This machine's entry in the file `fleet` wrote, if it has one.
  mine = (import ./generated/microvms.nix).${config.networking.hostName} or null;
in {
  config = lib.mkIf (mine != null) {
    # The VMs this machine runs (flake, autostart, restart behaviour)
    microvm.vms = lib.mapAttrs (_: vm: vm // {flake = inputs.self;}) mine.vms;
    # The directories those VMs share
    systemd.tmpfiles.rules = mine.tmpfiles;
    # Which VM starts after which
    systemd.services = mine.units;
    # Which bridge each VM's network cable plugs into (only if you turn on tapRules)
    systemd.network.networks = lib.listToAttrs (map (t:
      lib.nameValuePair "28-${t.name}" {
        matchConfig.Name = t.name;
        networkConfig.Bridge = t.bridge;
        linkConfig.RequiredForOnline = "enslaved";
      }) (mine.tapRules or []));
  };
}
```

Then tell git about all the new files:

```bash
git add network flake.nix
```

## Step 4: write your first record

Pick any NixOS machine you already have. This example is a file server called `nas`. Create
`systems/x86_64-linux/nas/host.nix` next to its `default.nix`:

```nix
# systems/x86_64-linux/nas/host.nix
{...}: {
  fmf.host = {
    kind = "physical";
    network.interfaces.lan = {
      ip = "192.168.50.30";
      mac = "aa:bb:cc:00:00:30";
      zone = "lan";
    };
  };
}
```

Read it as: "`nas` is a physical machine. It has one network interface, which I will call `lan`. That interface
has this address and this MAC, and is in the `lan` zone."

| Field | Meaning |
|---|---|
| `kind` | `"physical"` or `"microvm"`. Required. A machine without `kind` is ignored by the fleet. |
| `network.interfaces.<name>` | One block per network card. The name is yours (`lan`, `eth`, `wifi`). |
| `ip` | The machine's address. `null` means it gets one from DHCP and nothing is reserved. |
| `mac` | The card's hardware address. A lease needs it; so does a MicroVM. |
| `zone` | Which network it is in. Must exist in `zones.nix`. |

`static` is the one setting people stumble on:

- **`static = false`** (the default for a physical machine): the machine asks DHCP, and the generated lease makes
  DHCP always answer with this address.
- **`static = true`** (the default for a MicroVM): the machine sets its own address. A lease is still generated,
  so nothing else is given that address.

```bash
git add systems/x86_64-linux/nas/host.nix
```

## Step 5: run `fleet`

From the root of your flake:

```bash
nix run --inputs-from . fmf#fleet
```

`--inputs-from .` means "use the `fmf` that my flake is locked to". Expect it to take a while the first time: it
is evaluating every machine. When it finishes:

```
wrote network/generated/: 1 host leases, 2 DNS names, 0 port forwards, 0 generated MicroVMs (1 active hosts, 0 standby, 0 retired)
```

Look at what it wrote:

```nix
# network/generated/leases.nix
{
  "lan" = [
    {mac = "aa:bb:cc:00:00:30"; ip = "192.168.50.30"; hostname = "nas";}
  ];
}
```

```nix
# network/generated/dns.nix
{
  "nas" = "192.168.50.30";
  "nas.lan-hosts.example.com" = "192.168.50.30";
}
```

Those files are your machine's data in the shape a DHCP server and a DNS server want. Commit them with the record:

```bash
git add network systems
git commit -m "fleet: first host record"
```

Two more commands you will use constantly:

```bash
nix run --inputs-from . fmf#fleet -- --check        # are the committed files up to date? (changes nothing)
nix run --inputs-from . fmf#fleet -- --show nas     # what is derived for one machine (changes nothing)
```

## What you have now, and what is next

- Your flake loads records and zones.
- One machine is described once, and its lease and names are generated.
- Nothing on any machine has changed yet: no generated file is read by anything. That happens in the next
  tutorials, one consumer at a time.

Go on to [MicroVMs from records](FLEET-TUTORIAL-VMS.md), [Leases, DNS and port forwards from
records](FLEET-TUTORIAL-NETWORK.md), or both.

## What was and was not tested

The flake, zones, reader module and records on this page were run in a scratch downstream flake against this
repository's `fmf`: `fleet` wrote the files shown, and the hosts evaluated. Booting a machine from them and
deploying to real hardware were not done.
