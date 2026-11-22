---
type: Host
title: pikvm — Raspberry Pi 4 KVM-over-IP example
description: A Raspberry Pi 4 PiKVM reference configuration that uses nixos-raspberrypi's cached kernel and cache, so a first build fetches the kernel instead of compiling it.
resource: ./default.nix
tags: [pikvm, raspberry-pi, arm64, example]
---

# pikvm (example)

A reference for a Raspberry Pi 4 running [`fmf.services.pikvm`](../../../modules/nixos/services/pikvm/README.md)
(kvmd, nginx, Janus). It is an example flake output, not a deployment: no fleet record, address,
SSH key, Vault credential or private cache is in it. The live host is in the downstream Campground flake.

## What it shows

- **The cached kernel.** `boot.kernelPackages` is
  `inputs.nixos-raspberrypi.packages.<system>.linuxPackages_rpi4`, the package set that
  [nvmd/nixos-raspberrypi](https://github.com/nvmd/nixos-raspberrypi)'s own `raspberry-pi-4.base` module
  selects. The flake input has **no `follows`**: its binary cache only holds outputs built against its own
  nixpkgs, so following ours would change the kernel derivation and compile it from source.
- **The cache.** `nixos-raspberrypi.cachix.org` and its key are in the host's own `nix.settings`. The host
  leaves `fmf.nix` off (it adds deploy-rs, every host's closure and a netrc sidecar), so the list in
  `fmf.suites.common` does not apply to it.
- **U-Boot/extlinux, not systemd-boot.** The boot path comes from `nixos-hardware`'s `raspberry-pi-4` module
  and the SD-image module; the Pi kernel package set is the only thing taken from nixos-raspberrypi.
- **Two build traps avoided**, both found by trying it:
  1. The generic `sd-image-aarch64` profile enables `hardware.enableAllHardware`, which asks the initrd for
     drivers of other boards such as Rockchip `dw-hdmi`. The Pi kernel does not ship them, so the initrd
     fails with `Module dw-hdmi not found`. `hardware.enableAllHardware = false` fixes it.
  2. nixpkgs builds `avrdude` with its PDF manual by default, which pulls TeX Live, Asymptote and ImageMagick,
     none of which is in the public aarch64 cache. The kvmd package uses `avrdude` without docs.
- fmf's shared home module sets `EDITOR` to the custom Neovim build, which also drags ImageMagick in; the
  example sets `EDITOR` to nano.

## Using it

```sh
nix eval --raw .#nixosConfigurations.pikvm.config.system.build.toplevel.drvPath   # evaluate only
nix build --dry-run .#nixosConfigurations.pikvm.config.system.build.toplevel      # what would build or fetch
nix build .#nixosConfigurations.pikvm.config.system.build.sdImage                 # the SD card image
```

Before flashing an image, set `users.users.admin.openssh.authorizedKeys.keys` in a downstream config:
password login is off and the account has no password, so with no key nobody can log in.

## What is and is not verified

- The kernel output equals nixos-raspberrypi's and is present in its Cachix cache.
- The `avrdude` change was checked on the derivation: `kvmd`'s closure no longer contains TeX Live,
  Asymptote or ImageMagick (only `texinfo`, which `cache.nixos.org` has).
- **Evaluating this host needs an `aarch64-linux` builder.** The PiKVM module reads files out of the
  `kvmd` package while evaluating, so `nix eval` builds `kvmd` (and the docs-free `avrdude`) first. From an
  x86_64 machine that means a configured aarch64 builder (or binfmt emulation).
- **Not done:** a full evaluation or dry run after the `avrdude` change, an image build, and a boot on a Pi.
  Whatever is not in `cache.nixos.org` or the Raspberry Pi cache (kvmd itself, the initrd) builds on the
  first run; those are small.
