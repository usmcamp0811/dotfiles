---
type: Tutorial
title: Install NixOS on a new machine
description: Put NixOS on a blank machine from a flake that uses fmf, with the disks described in code by disko - either from the installer USB on the machine, or remotely with nixos-anywhere - and what to do on first boot.
tags: [install, disko, nixos-anywhere, tutorial, getting-started]
status: draft
---

# Install NixOS on a new machine

By the end you will have a machine running NixOS whose **whole configuration, including its disk
layout, lives in a git repository**. Reinstalling it, or building a second one like it, is one command.

> **Status: draft.** The host files below were evaluated and the whole system built as a derivation
> (`nix eval ...toplevel.drvPath`), and the disko and nixos-anywhere options were checked against the
> versions fmf pins and their `--help`. A complete install was **not** run on hardware or in a VM while
> this was written. Try it on a spare machine, or with `--vm-test` (below), before you trust it with one
> that matters.

## Choose a method

| Method | You need | Pick it when |
| --- | --- | --- |
| **A. Installer USB** (this page) | Physical access, a USB stick | One machine, and you are sitting at it |
| **B. nixos-anywhere** (this page) | Another computer, SSH access to the target | A server, a VM, a cloud instance, or several machines |
| **C. By hand** | Physical access | You want to partition yourself: [Reformat and install NixOS](Install.md) |

For a larger real-world example with encryption and a wiped root, read
[Blue Ridge installation](../systems/x86_64-linux/blue-ridge/INSTALL.md).

## Before you start

You need **a flake with a host in it**. If you do not have one, make it first:
[Use fmf from your own flake](DOWNSTREAM-FLAKE.md), then [Add a system to your flake](NEW-SYSTEM.md). The
examples below use a host called `laptop`.

Three things to settle:

1. **The target disk.** Boot any Linux on the machine and run `lsblk`. disko **erases the whole disk** it
   is pointed at; there is no dual-boot mode.
2. **UEFI.** fmf's `fmf.system.boot` uses systemd-boot. Boot the installer in UEFI mode.
3. **A backup**, if the machine holds anything you want.

### The disk layout: `disko.nix`

[disko](https://github.com/nix-community/disko) turns a description of partitions and filesystems into
the partitioning commands *and* the matching `fileSystems` entries, so the layout is written once. Create
`systems/x86_64-linux/laptop/disko.nix`:

```nix
# One disk: a 1 GiB EFI system partition and an ext4 root on the rest.
# disko turns this into the `fileSystems` entries, so hardware.nix must not list any.
{
  disko.devices.disk.main = {
    type = "disk";
    device = "/dev/nvme0n1"; # check with `lsblk` on the installer
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          size = "1G";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = ["umask=0077"];
          };
        };
        root = {
          size = "100%";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/";
          };
        };
      };
    };
  };
}
```

The host must import disko's NixOS module and this file. fmf does not add the module to every host, so
do it in `systems/x86_64-linux/laptop/default.nix`:

```nix
  imports = [
    inputs.disko.nixosModules.disko
    ./hardware.nix
    ./disko.nix
  ];
```

The complete `default.nix` is in [Add a system to your flake](NEW-SYSTEM.md). Other layouts (ZFS, Btrfs,
LUKS, several disks) are in the
[disko examples](https://github.com/nix-community/disko/tree/master/example); fmf's own
`systems/x86_64-linux/blue-ridge/disko.nix` shows a real one.

### The hardware file

`hardware.nix` describes the machine's CPU, drivers and kernel modules. Generate it **on the target
machine**, and leave the filesystems out, because disko provides them:

```bash
sudo nixos-generate-config --no-filesystems --show-hardware-config > systems/x86_64-linux/laptop/hardware.nix
```

Delete the template's placeholder `hardware.nix` first: it lists filesystems and a fixed boot-partition
UUID that belong to nobody's machine.

## Method A: from the installer USB

**1. Make the installer.** Use [the fmf live ISO](LIVE-ISO.md), which boots into a desktop with a
terminal, a browser, the Vault CLI and these install tools, or the official minimal ISO from
[nixos.org](https://nixos.org/download/#nixos-iso). Write it to a USB stick. Check the device name with
`lsblk` first; `dd` overwrites whatever you name.

```bash
sudo dd if=<the-image>.iso of=/dev/sdX bs=4M status=progress conv=fsync
```

**2. Boot it** in UEFI mode and get a network connection. A cable just works. For Wi-Fi follow the
networking section of the [installation chapter of the NixOS manual](https://nixos.org/manual/nixos/stable/#ch-installation).

**3. Turn on flakes and fetch your configuration.**

```bash
export NIX_CONFIG='experimental-features = nix-command flakes'
git clone https://example.com/you/your-flake.git
cd your-flake
```

**4. Generate the hardware file** on this machine (see above), then track it, because flakes ignore
untracked files:

```bash
sudo nixos-generate-config --no-filesystems --show-hardware-config > systems/x86_64-linux/laptop/hardware.nix
git add systems/x86_64-linux/laptop/hardware.nix
```

**5. Preview, then partition.** `--dry-run` only prints the script that would run:

```bash
sudo nix run github:nix-community/disko/latest -- --mode destroy,format,mount --dry-run --flake .#laptop
sudo nix run github:nix-community/disko/latest -- --mode destroy,format,mount --flake .#laptop
```

The second command asks you to confirm before it erases the disk (`--yes-wipe-all-disks` skips the
question, for automation) and leaves the new filesystems mounted under `/mnt`.

**6. Install.**

```bash
sudo nixos-install --flake .#laptop --no-root-passwd
```

`--no-root-passwd` skips the root password prompt; root logs in with an SSH key only. The main user starts
with the password `password` (an fmf default), which you will change on first login.

**7. Reboot**, remove the USB stick, and go to [First boot](#first-boot).

## Method B: remotely with nixos-anywhere

[nixos-anywhere](https://github.com/nix-community/nixos-anywhere) logs in to a running Linux machine over
SSH, boots a NixOS installer in its memory (kexec), runs disko, installs your host and reboots. The
target needs SSH access as `root` (or a user with passwordless sudo) and enough RAM to hold the
installer; see its README for the details.

```bash
# On your own computer, in your flake. 192.168.50.50 is an example address.
nix run github:nix-community/nixos-anywhere -- \
  --flake .#laptop \
  --generate-hardware-config nixos-generate-config ./systems/x86_64-linux/laptop/hardware.nix \
  --target-host root@192.168.50.50

git add systems/x86_64-linux/laptop/hardware.nix
```

`--generate-hardware-config` writes `hardware.nix` from the target machine. Run the command once with
it, commit the file, and leave the option out afterwards.

Useful options (all in `nixos-anywhere --help`):

| Option | Use |
| --- | --- |
| `--vm-test` | Build the system and **test the disk layout in a VM without installing anything**. Run this first. |
| `--build-on-remote` | Build on the target instead of copying the closure, for a different architecture |
| `--copy-host-keys` | Keep the target's existing SSH host keys |
| `--extra-files <dir>` | Copy the files in `<dir>` onto the new system, for example host keys or secrets |
| `--disk-encryption-keys <remote> <local>` | Supply a LUKS or ZFS key to the installer |
| `--phases kexec,disko,install,reboot` | Run only some of the steps |

## First boot

Log in as your user (`alice` in the examples) with the password `password`, then:

```bash
passwd                                   # change it now
sudo nixos-rebuild switch --flake .#laptop   # once your flake is on the machine
```

Check that nothing you did not intend is reachable:

```bash
ss -tlnp                                 # listening services; SSH is on ports 22 and 2222
sudo grep -r . /etc/ssh/authorized_keys.d    # whose keys are accepted: they should all be yours
```

Put your flake on the machine (clone it into the user's home) so you can change it from there, or keep
managing it from another computer with [deploy-rs](COMMON-TASKS.md#deploy-a-host).

## When something goes wrong

| Symptom | Cause and fix |
| --- | --- |
| `couldn't find 'diskoConfigurations.laptop' or 'nixosConfigurations.laptop.config.disko.devices'` | The host does not import `inputs.disko.nixosModules.disko`, or has no `disko.devices`. Add the import and `disko.nix`, and `git add` them. |
| `Attribute 'nixosConfigurations.laptop.config.system.build.diskoScript' not found in flake` | The disko you ran differs from the one locked in your flake. Set the flake's `disko` input to `github:nix-community/disko/latest` and `nix flake update disko`, or run the version you locked. |
| `error: experimental Nix feature 'flakes' is disabled` | `export NIX_CONFIG='experimental-features = nix-command flakes'` in the installer. |
| Nix cannot find a file you created | Flakes only see files git tracks. `git add` it. |
| ``The option `fileSystems."/".fsType' has conflicting definition values`` | `hardware.nix` was generated without `--no-filesystems`, so it and disko both define the filesystems. Regenerate it with the flag. |
| The bootloader step fails during `nixos-install` | systemd-boot needs UEFI and the installer was booted in legacy BIOS mode. Boot the installer in UEFI mode and install again. |

## Next

* [Add a system to your flake](NEW-SYSTEM.md) for what goes in `default.nix`.
* [More than one user on a host](MULTI-USER-HOSTS.md).
* [Common tasks](COMMON-TASKS.md) for updating and deploying.
