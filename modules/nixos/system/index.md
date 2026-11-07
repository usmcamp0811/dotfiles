# Subdirectories

* [boot](boot/README.md) - systemd-boot with automatic boot assessment (boot counting), so a generation that never finishes booting is skipped in favour of an older one.
* [host](host/README.md) - One per-machine declaration (kind, lifecycle, interfaces and zones, MicroVM placement and storage, boot order, DNS, exposure, Vault, topology) read by lib.fmf.fleet; declares data only.
* [passwds](passwds/README.md) - This module provides a way to set local user passwords using Vault in NixOS.
* [wifi](wifi/README.md) - Store WiFi passwords in Vault and consume them from NixOS, with KV v1 or v2.
* [zfs](zfs/) - This NixOS module enables encrypted ZFS root partitions, featuring options for manual and automated unlocking.
