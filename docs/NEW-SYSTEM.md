---
type: Tutorial
title: Add a system to your flake
description: Create a new host in a flake that uses fmf - the three files, the user and its home, how to build it without changing anything, and how to switch to it - using a laptop called "laptop" as the example.
tags: [hosts, systems, tutorial, getting-started, snowfall]
---

# Add a system to your flake

A machine is a directory. By the end of this page you will have a new host in your flake that builds, and
you will know where each setting goes. The example is a laptop called `laptop`, used by `alice`.

You need a flake that already uses fmf. If you do not have one, start with
[Use fmf from your own flake](DOWNSTREAM-FLAKE.md). Everything here also applies to adding a host to fmf
itself; the layout is the same.

> Every file on this page was evaluated together in a scratch flake made from the downstream template
> (`nix eval ...nixosConfigurations.laptop.config.system.build.toplevel.drvPath` succeeds). The result was
> not built or booted.

## 1. Make the directories

Snowfall reads the names, so they matter: the **architecture** directory, then the **host name**; and for
the user, `<user>@<host>`.

```bash
mkdir -p systems/x86_64-linux/laptop "homes/x86_64-linux/alice@laptop"
```

The host name `laptop` becomes the flake output `nixosConfigurations.laptop` **and** the machine's
hostname; you do not set `networking.hostName` yourself.

## 2. The hardware file

`hardware.nix` says which CPU, drivers and kernel modules the machine needs. Never write it by hand.
Generate it **on the target machine**.

If the machine **already runs NixOS** and keeps its current disks:

```bash
nixos-generate-config --show-hardware-config > systems/x86_64-linux/laptop/hardware.nix
```

If this is a **new install** where disko will lay out the disks, leave the filesystems out:

```bash
nixos-generate-config --no-filesystems --show-hardware-config > systems/x86_64-linux/laptop/hardware.nix
```

and add a `disko.nix` as described in [Install NixOS on a new machine](INSTALL-NIXOS.md). Do not use both
kinds of file: they define the same filesystems twice.

## 3. The system

Create `systems/x86_64-linux/laptop/default.nix`:

```nix
{
  inputs,
  lib,
  ...
}:
with lib.fmf; {
  imports = [
    inputs.disko.nixosModules.disko
    ./hardware.nix
    ./disko.nix
  ];

  # Crystal Forge's STIG hardening presets are on by default for hosts that import its modules.
  crystal-forge.stig-presets.off.enable = true;

  fmf = {
    system.boot = enabled;

    user = {
      name = "alice";
      fullName = "Alice Example";
      email = "alice@example.com";
      extraGroups = ["wheel"];
    };

    services.openssh = {
      enable = true;
      # Replace fmf's default list instead of adding to it: the defaults are the
      # author's keys, and they would otherwise be accepted for you and for root.
      authorizedKeys = lib.mkForce [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIExampleExampleExampleExampleExampleExampleExamp alice@example.com"
      ];
    };
  };

  # Keys only over SSH. fmf.user.initialPassword is "password" until you run `passwd`.
  services.openssh.settings.PasswordAuthentication = false;

  system.stateVersion = "26.05";
}
```

For a machine that is **not** using disko, drop the `inputs.disko...` and `./disko.nix` lines from
`imports`. What each part does:

| Part | Why it is there |
| --- | --- |
| `with lib.fmf;` | brings `enabled` into scope: `system.boot = enabled;` means `system.boot.enable = true;` |
| `crystal-forge.stig-presets.off.enable` | the downstream flake imports Crystal Forge's modules, whose STIG hardening presets are on by default and currently fail evaluation. See [Start here](START-HERE.md#before-you-copy-anything). |
| `fmf.system.boot` | the bootloader (systemd-boot, so the machine must be UEFI) |
| `fmf.user` | the **main user**: name, groups, UID. Other users are separate homes, see below. |
| `fmf.services.openssh` | the SSH server, with **your** key. `lib.mkForce` is what stops the author's keys being added; leave it in. |
| `PasswordAuthentication = false` | no password logins over SSH |
| `system.stateVersion` | the NixOS release this machine was **first installed** with (`26.05` here; use the release you actually install). Set it once and do not raise it to upgrade. |

**This host does not use an archetype**, on purpose. `barebones`, `server`, `workstation` and `laptop` all
switch on `fmf.suites.common`, which enables a Crystal Forge agent, a build-farm client and caches that
belong to the author. See [How fmf is put together](HOW-FMF-WORKS.md#modules-suites-and-archetypes).
Enable the modules you want instead.

### Adding a feature

Every fmf feature is a module with an `enable` option. To run Docker, add one line inside `fmf = { ... }`:

```nix
    services.docker = enabled;
```

To find what exists, read `modules/index.md` or the generated **options** section of this site; each
module's `README.md` says what it does and which options it has.

## 4. The user's home

Create `homes/x86_64-linux/alice@laptop/default.nix`:

```nix
{lib, ...}:
with lib.fmf; {
  fmf = {
    user = {
      enable = true;
      name = "alice";
      fullName = "Alice Example";
      email = "alice@example.com";
    };

    cli.misc = enabled;
    tools.git = enabled;
  };

  home.stateVersion = "26.05";
}
```

This is [Home Manager](https://nix-community.github.io/home-manager/): the user's shell, tools and dotfiles.
The home can only set per-user options. Anything about the system itself, such as a service or the user's
UID, goes in the host's `default.nix`. A second user is a second folder; see
[More than one user on a host](MULTI-USER-HOSTS.md).

## 5. Check it

Flakes only see files git knows about:

```bash
git add systems/x86_64-linux/laptop homes/x86_64-linux/alice@laptop
```

Evaluate it, which is quick and finds most mistakes, then build it, which changes nothing on any machine:

```bash
nix eval --raw .#nixosConfigurations.laptop.config.system.build.toplevel.drvPath
nix build .#nixosConfigurations.laptop.config.system.build.toplevel
```

Read a single option back to confirm what you set:

```bash
nix eval --json .#nixosConfigurations.laptop.config.services.openssh.settings.PasswordAuthentication
nix eval --json .#nixosConfigurations.laptop.config.users.users.root.openssh.authorizedKeys.keys
```

The second must print **only your key**. If it prints others, the `lib.mkForce` is missing.

## 6. Put it on the machine

| The machine is... | Do this |
| --- | --- |
| a fresh, blank machine | [Install NixOS on a new machine](INSTALL-NIXOS.md) |
| already running NixOS, and you are logged in to it | `sudo nixos-rebuild switch --flake .#laptop` |
| already running NixOS, and you are on another computer | `nixos-rebuild switch --flake .#laptop --target-host root@192.168.50.50` or `deploy .#laptop` |

`192.168.50.50` is an example address. The first time you switch an existing machine to your flake, keep
a way in: switching changes users, SSH and the boot menu. The previous generation stays in the boot menu,
so a bad switch can be undone by choosing it.

## Next

* [More than one user on a host](MULTI-USER-HOSTS.md)
* [Common tasks](COMMON-TASKS.md): updating, deploying, rolling back.
* [How fmf is put together](HOW-FMF-WORKS.md), if a term here was new.
* Many hosts, MicroVMs, DNS and DHCP from one description:
  [Getting started with the fleet](FLEET-GETTING-STARTED.md).
