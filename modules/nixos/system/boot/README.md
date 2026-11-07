---
type: NixOS Module
title: Boot (fmf.system.boot)
description: systemd-boot with automatic boot assessment (boot counting), so a generation that never finishes booting is skipped in favour of an older one.
resource: ./default.nix
tags: [system, boot]
---

# Boot (`fmf.system.boot`)

Enabled for every host by `fmf.suites.common`. Turns on systemd-boot (UEFI), keeps the last five
generations, and disables the boot-menu editor. MicroVMs force systemd-boot off and are unaffected.

## Boot counting

```nix
fmf.system.boot.boot-counting = {
  enable = true; # default
  tries = 3;     # default
};
```

Uses systemd's [Automatic Boot Assessment](https://systemd.io/AUTOMATIC_BOOT_ASSESSMENT/) through
nixpkgs' `boot.loader.systemd-boot.bootCounting`. A new generation's boot entry is written with a
counter. Each boot decrements it; once the system reaches `boot-complete.target`,
`systemd-bless-boot.service` marks the entry good. An entry whose counter hits zero is sorted last, and
systemd-boot boots an older generation instead.

- **Only where systemd-boot is enabled.** It is applied only when `boot.loader.systemd-boot.enable` is
  true, so a MicroVM or a host with another loader gets nothing.
- **Needs a nixpkgs that has the option.** It is not in `release-26.05` (checked at rev `c5062e80`);
  it is in `nixos-unstable` (26.11). On a nixpkgs without it the module detects that the option does not
  exist and does nothing, so enabling this is safe everywhere and starts working when the consumer's
  nixpkgs gains it. To see whether a host has it, read
  `config.boot.loader.systemd-boot.bootCounting.enable`: `true` means active, and the attribute missing
  means its nixpkgs predates the feature.
- **What it detects.** Failure to *boot*: the kernel, the initrd or stage 2 not reaching
  `boot-complete.target`. By default that target is reached early, so it does **not** notice a
  generation that boots but breaks networking or a service. Gating on services needs units ordered
  `Before=boot-complete.target`.
- **Existing entries** have no counter and count as good; only entries written after enabling it are
  assessed.
- **A machine that fails to boot for an unrelated reason** (for example the Tang server being
  unreachable at LUKS unlock) spends the new generation's tries and falls back, which does not help but
  does no harm. A fallback generation that needs the same thing fails in the same way.

## Anything that reads loader.conf must allow for counting

With counting on, the nixpkgs builder stops writing `default <entry>.conf`. It writes

```
preferred nixos-<hash>.conf
default nixos-*
```

and the entry file on disk is `nixos-<hash>+3.conf` (or `+2-1` after a failed try). A script that reads
the `default` line and tests `entries/<that>` as a file name sees the literal glob `nixos-*` and fails.
Read `preferred` first, and look for the entry with or without a counter suffix. Campground's `webb`
install hook does this.

Upstream covers the feature with NixOS tests (`systemd-boot.bootCounting`,
`defaultEntryWithBootCounting`, `garbageCollectEntryWithBootCounting`).
