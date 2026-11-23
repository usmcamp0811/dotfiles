---
type: Guide
title: The fmf live ISO
description: A live USB image with a Hyprland desktop, kitty, Brave, the Vault CLI and the tools to partition, install and bootstrap a host from a flake - where to download it, what is on it, how it is built every month, and how to build or change it yourself.
tags: [iso, install, live-usb, ci, getting-started]
status: draft
---

# The fmf live ISO

A bootable image for bringing up a new machine: it starts straight into a [Hyprland](https://hypr.land/)
desktop, with a terminal, a browser, the Vault CLI and everything needed to partition a disk, fetch your
flake and install from it. It is built from this repository every month.

> **Status: draft.** The image builds and its configuration was checked, as described under
> [What was checked](#what-was-checked). Read that section before you rely on it.

## Download

| | |
| --- | --- |
| **Latest image** | [`fmf-installer-x86_64.iso`](https://gitlab.com/usmcamp0811/dotfiles/-/releases/permalink/latest/downloads/fmf-installer-x86_64.iso) |
| **Checksums** | [`SHA256SUMS`](https://gitlab.com/usmcamp0811/dotfiles/-/releases/permalink/latest/downloads/SHA256SUMS) |
| **All releases** | [the releases page](https://gitlab.com/usmcamp0811/dotfiles/-/releases) |

Only the newest two images are kept, so an older release's link stops working once it is pruned. The
"latest" link always points at the newest one.

Check the download, then write it to a USB stick. `lsblk` first: `dd` overwrites whatever device you name.

```bash
sha256sum -c SHA256SUMS
sudo dd if=fmf-installer-x86_64.iso of=/dev/sdX bs=4M status=progress conv=fsync
```

Boot the stick in **UEFI** mode. The image is x86_64 only.

## What is on it

* **Desktop:** Hyprland with waybar, rofi and wofi launchers, notifications, a network applet, a lock
  screen and wallpapers, started by SDDM. The live user, `nixos`, is logged in automatically.
* **Applications:** kitty (the terminal) and Brave.
* **Secrets:** the Vault CLI (and `consul`). `VAULT_ADDR` is set to the maintainer's own Vault, so set
  your own: `export VAULT_ADDR=https://vault.example.com`.
* **Install:** `nixos-install`, `nixos-generate-config`, `disko`, `git`, and the fmf install scripts.
* **Disks:** `parted`, `gdisk`, LUKS (`cryptsetup`), Btrfs, ext4, FAT, XFS, NTFS, LVM, `mdadm`, `nvme-cli`,
  `smartmontools`, and ZFS support. `clevis` is there to unlock a disk bound to a Tang server.
* **Network:** NetworkManager (the applet in the bar, or `nmtui` in a terminal), `iw`, `ethtool`, `tcpdump`.
* **Everyday:** neovim, tmux, htop, curl, wget, jq, ripgrep, rsync, `age`, `mkpasswd` (from `whois`).

Flakes are on, so you can install straight from the terminal:

```bash
git clone https://example.com/you/your-flake.git && cd your-flake
sudo nix run github:nix-community/disko/latest -- --mode destroy,format,mount --flake .#<host>
sudo nixos-install --flake .#<host> --no-root-passwd
```

[Install NixOS on a new machine](INSTALL-NIXOS.md) walks through it, including the hardware file.

## Who can log in

The image is public, so it is built to be safe to boot on a network:

* **No SSH keys are baked in.** fmf's defaults would add the maintainer's keys; the image replaces them with
  none.
* **The live user has no password**, as on the official installer. You are logged in on the console
  automatically, and `sudo` does not ask for a password.
* **SSH works only after you open it:** set a password with `passwd`, or add a public key to
  `~/.ssh/authorized_keys`. Nothing can log in remotely before then.

## Build it yourself

```bash
nix build .#install-isoConfigurations.installer
ls result/iso/                     # the .iso is here
```

To try it without a USB stick:

```bash
nix shell nixpkgs#qemu --command qemu-system-x86_64 -enable-kvm -m 6G -smp 4 \
  -cdrom result/iso/*.iso -vga virtio
```

The configuration is two files: `systems/x86_64-install-iso/installer/default.nix` (what is installed
and who can log in) and `homes/x86_64-install-iso/nixos@installer/default.nix` (the desktop). To bake in
your own SSH key, set `fmf.services.openssh.authorizedKeys = lib.mkForce [ "ssh-ed25519 AAAA..." ];` in the
first.

It deliberately uses no archetype and not `fmf.system.zfs`: they carry the maintainer's fleet settings
(see [Start here](START-HERE.md#before-you-copy-anything)), which do not belong on an image that boots on
someone else's hardware.

## How it is published

The `build_iso` job in `.gitlab-ci.yml` builds the image and runs `.gitlab/publish-iso.sh`, which:

1. uploads the image and `SHA256SUMS` to the project's generic package registry, as
   `fmf-installer/<YYYY.MM.DD>/`;
2. creates a release `iso-<YYYY.MM.DD>` whose asset paths are fixed (`/fmf-installer-x86_64.iso`), which is
   what makes the "latest" link permanent;
3. deletes all but the newest two images, with their releases and tags, because every image counts
   against the project's storage quota.

The image goes to the package registry and not into git, because a multi-gigabyte file committed to git
stays in the history for good.

**To run it every month**, add a schedule (this is a setting in GitLab, not a file in the repository):
CI/CD, Schedules, New schedule, branch `nixos`, interval pattern `0 3 1 * *`, and a variable
`BUILD_ISO` = `true`. **To publish one now**, press play on `build_iso` in any pipeline on the default
branch.

Pruning needs a `GITLAB_TOKEN` CI variable with the `api` scope (the renovate job already uses one);
without it the job still publishes and prints a warning, and old images stay. The image is built from the
default branch as it is, so keep `flake.lock` current if you want fresh kernels and packages in it.

## What was checked

* The image **builds** from this repository (`nix build .#install-isoConfigurations.installer`).
* `.gitlab/publish-iso.sh` passes `shellcheck`, and a dry run against a canned package list kept the newest
  two images, selected the rest for pruning, and produced a valid release payload.
* The CI job definition parses.

**Not checked:** the publishing job has not run on a real pipeline, so the first run is the real test of the
upload, the release and the "latest" link. Confirm that the link downloads without logging in to GitLab.
