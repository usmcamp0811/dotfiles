---
type: Host
title: krulak — ARM64 NixOS example
description: An Orange Pi 6 Plus reference configuration with encrypted Btrfs, an ephemeral root, and key-only SSH, named for Marine Lieutenant General Victor Krulak.
resource: ./default.nix
tags: [krulak, arm64, disko, impermanence, example]
---

# Victor “Brute” Krulak

Victor Harold Krulak (1913–2008) was a United States Marine Corps lieutenant
general. He served in World War II, Korea, and Vietnam and later commanded
Fleet Marine Force, Pacific. He helped develop Marine amphibious doctrine and
advocated for helicopter mobility. He wrote *First to Fight: An Inside View of
the U.S. Marine Corps*.

![Portrait of General Charles C. Krulak](https://upload.wikimedia.org/wikipedia/commons/0/0f/Charles_C._Krulak.jpg)

*Pictured: General Charles C. Krulak, Victor Krulak’s son. The host is named for
Victor. [Image source: Wikimedia Commons](https://commons.wikimedia.org/wiki/File:Charles_C._Krulak.jpg).*

## About this example

This is the public reference for the Orange Pi 6 Plus setup used in Campground.
It is a separate `aarch64-linux` flake output, not the live Krulak configuration.
It has no fleet enrollment, DHCP reservation, SSH keys, Vault credentials, or
build-farm endpoints. It is not a CI deployment target.

- **Boot:** UEFI with systemd-boot, following the live system's ARM64 setup.
- **Storage:** Disko creates a FAT EFI partition and puts Btrfs `/home`, `/nix`,
  and `/persist` inside LUKS. Root is tmpfs. The disk passphrase is entered at
  the console before networking and SSH start.
- **SSH:** NixOS generates `/etc/ssh`; only the host key lives under `/persist`.
  The `admin` account has no password, and root SSH is disabled. Supply your
  own public key before deploying.
- **Packages:** Uses nixpkgs' stable Nix and system-wide Git. It avoids workstation
  profiles and the ImageMagick dependencies they pull in.

The live host layers on a native `aarch64-linux` build-farm worker, Vault-issued
worker credentials, and Niks3 uploads for local builds. Those are site-specific
additions: see the fmf `nix-grpc-store` and `niks3-auto-upload` service modules.

## Evaluate without installing

From the fmf checkout:

```sh
nix eval --raw .#nixosConfigurations.krulak.config.system.build.toplevel.drvPath
```

This evaluates the example; it does not build it, format a disk, or prove that
the current kernel boots on a particular board. Before adapting it for an
install, verify the board's UEFI and kernel support, replace the placeholder
NVMe by-id path, add your public key, and keep a recovery console available.
