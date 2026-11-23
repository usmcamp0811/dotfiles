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

> **Status: draft.** The configuration evaluates and its whole system closure builds, but the finished
> image has not yet been booted. Read [What was checked](#what-was-checked) before you rely on it.

## Download

| | |
| --- | --- |
| **Latest image** | [`fmf-installer-x86_64.iso`](https://gitlab.com/usmcamp0811/dotfiles/-/releases/permalink/latest/downloads/fmf-installer-x86_64.iso) |
| **Checksums** | [`SHA256SUMS`](https://gitlab.com/usmcamp0811/dotfiles/-/releases/permalink/latest/downloads/SHA256SUMS) |
| **All releases** | [the releases page](https://gitlab.com/usmcamp0811/dotfiles/-/releases) |

Only the newest image is kept (it is about 3 GB, and the project's storage is limited), so an older release's link stops working once it is pruned. The
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
* **Secrets:** the Vault CLI (`vault`). `VAULT_ADDR` is not set, because the image is public: point it at
  your own server, `export VAULT_ADDR=https://vault.example.com`.
* **Install:** `nixos-install`, `nixos-generate-config`, `disko`, `git`, and the fmf install scripts.
* **Disks:** `parted`, `gdisk`, LUKS (`cryptsetup`), Btrfs, ext4, FAT, XFS, NTFS, LVM, `mdadm`, `nvme-cli`,
  `smartmontools`, and ZFS support. `clevis` is there to unlock a disk bound to a Tang server.
* **Network:** NetworkManager (the applet in the bar, or `nmtui` in a terminal), `iw`, `ethtool`, `tcpdump`.
* **Everyday:** vim, tmux, htop, btop, fzf, bat, lsd, fastfetch, curl, wget, jq, ripgrep, rsync, `age`,
  `mkpasswd` (from `whois`). It is plain `vim`, not neovim: in this flake `neovim` is my full
  distribution, with a Rust toolchain and a JDK behind it, which would double the size of the image.

Flakes are on, so you can install straight from the terminal:

```bash
git clone https://example.com/you/your-flake.git && cd your-flake
sudo nix run github:nix-community/disko/latest -- --mode destroy,format,mount --flake .#<host>
sudo nixos-install --flake .#<host> --no-root-passwd
```

[Install NixOS on a new machine](INSTALL-NIXOS.md) walks through it, including the hardware file.

## Who can log in

The image is public, so it is built to be safe to boot on a network. This was read from the built
system, not just from the configuration:

* **No SSH keys are baked in.** fmf's defaults would add my keys; the image replaces them with none, and
  it has no `authorized_keys` files at all.
* **Neither `nixos` nor `root` has a password**, as on the official installer. You are logged in on the
  console automatically, and `sudo` does not ask for a password.
* **The SSH server does run from boot**, on ports 22 and 2222, and allows password logins, including for
  `root`, again as on the official installer. Nobody can log in remotely because no account has a password
  or a key, and the server refuses empty passwords. That changes the moment you run `passwd` or add a key
  to `~/.ssh/authorized_keys`, so set a strong password and do not leave the machine on an untrusted network
  after that.

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

It deliberately uses no archetype and not `fmf.system.zfs`: they carry my fleet settings
(see [Start here](START-HERE.md#before-you-copy-anything)), which do not belong on an image that boots on
someone else's hardware.

## How it is published

The `build_iso` job in `.gitlab-ci.yml` builds the image and runs `.gitlab/publish-iso.sh`, which:

1. uploads the image and `SHA256SUMS` to the project's generic package registry, as
   `fmf-installer/<YYYY.MM.DD>/`;
2. creates a release `iso-<YYYY.MM.DD>` whose asset paths are fixed (`/fmf-installer-x86_64.iso`), which is
   what makes the "latest" link permanent;
3. deletes every image but the newest, with its release and tag, because an image is about 3 GB and
   counts against the project's storage quota (`KEEP` changes how many stay).

GitLab.com rejects package files larger than 5 GB, which is why the image is kept lean (see
[What is on it](#what-is-on-it)); the script refuses a bigger one before uploading anything.

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

* The configuration **evaluates**, and its whole system closure builds (`nix build
  .#install-isoConfigurations.installer`). The final step, compressing the image, takes the better part
  of an hour.
* **In the built system** (read from the store, not booted): `kitty`, `brave`, `vault`, `Hyprland`,
  `nixos-install`, `disko`, `git`, `vim`, `nmtui`, `clevis` and the disk and network tools are present;
  `waybar`, `rofi`, `wofi`, `swaync` and `nm-applet` are in the live user's profile; none of my
  development tools (`nvim`, `rustc`, `gcc`, `clang`, `zig`, `deno`, `spotify`, `consul`) are; there are no
  SSH key files; SDDM logs `nixos` in to `hyprland.desktop`; and `nixos` and `root` have no password.
* **Size.** A first version of this image was 7.6 GB. It carried my full Neovim (with a Rust toolchain and a
  JDK), Spotify, clang, zig, deno, a second Vault and EasyEffects, because `fmf.tools.misc`, `fmf.cli.misc`,
  `fmf.cli.env`, the audio module and the Hyprland module pull them in. Removing those cut the system from
  26 GB to 11 GB. GitLab.com rejects package files over 5 GB, so the first version could not have been
  published at all.
* `.gitlab/publish-iso.sh` passes `shellcheck`, and a dry run against a canned package list kept the newest
  image, selected the rest for pruning, refused an image over the 5 GB package limit before sending anything,
  and produced a valid release payload. The CI job definition parses.

**Not checked yet:**

* **The finished image has not been booted.** What is said about it above comes from reading the built system,
  not from a running one. Boot it in a VM or on a spare machine and confirm it reaches the desktop before you
  publish a release.
* **The publishing job has not run on a real pipeline**, so the first run is the real test of the upload,
  the release and the "latest" link. Confirm that the link downloads without logging in to GitLab.
