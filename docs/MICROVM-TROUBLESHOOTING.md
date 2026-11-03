---
type: Troubleshooting
title: MicroVM boot and configuration pitfalls
description: Failures we hit bringing up fmf/Campground MicroVMs (stale store overlay, emergency mode, duplicate option definitions, surprise sudo and NetworkManager) with the check and the fix for each.
generated: { by: claude-agent/haiku-5-5, at: 2026-11-03T13:30:00-06:00 }
tags: [microvm, troubleshooting, nixos, vault]
---

# MicroVM boot and configuration pitfalls

Each entry is a real failure. Look for the symptom first, then run the check.

## Boot drops to "Emergency Mode" and says the root account is locked

**Symptom.** `Failed to start Switch Root` or `Failed to start NixOS Activation`, then
`You are in emergency mode` and `Cannot open access to console, the root account is locked`.

**This is not a password problem.** The emergency shell asks for a password only because
root is locked. Nothing needs to be typed. Find the real error instead:

```nix
# TEMPORARY: print initrd errors to the console (remove after debugging)
boot.kernelParams = [
  "systemd.journald.forward_to_console=1"
  "systemd.journald.max_level_console=debug"
];
boot.initrd.systemd.emergencyAccess = true; # passwordless emergency shell
```

Then `journalctl -fu microvm@<name>` on the host, and look for the first `[FAILED]` line
and the message just before it. Remove both settings afterwards.

Only define `boot.kernelParams` once per host. A second assignment fails with
`attribute 'boot.kernelParams' already defined`. Merge the lists instead.

## Activation fails with `No such file` for store paths, then `os-release file is missing`

**Symptom.** Inside the guest:

```text
Can't open perl script "/nix/store/…-setup-etc.pl": No such file or directory
cp: cannot stat '/nix/store/…-fino-root.zsh-theme': No such file or directory
Failed to switch root: Specified switch root path '/sysroot' does not seem to be an OS tree. os-release file is missing.
```

The `os-release` error is only the consequence. The activation snippets failed first.

**Cause.** The guest's `/nix/store` is an overlay: the host's store is the read-only lower
layer, and `/persist/vm-stores/<vm>/nix-store` is the writable upper layer. An overlay
**whiteout** (a 0-byte character device) in the upper layer hides a lower file that really
exists. These whiteouts come from an earlier, interrupted boot, so the guest sees paths
that are present on the host as missing.

**Check** (on the host):

```bash
sudo find /persist/vm-stores/<vm>/nix-store -type c | head     # whiteouts
sudo stat -c '%s %n' /persist/vm-stores/<vm>/nix-store/store/<hash>-<name>   # 0 = whiteout
sudo cmp /nix/store/<hash>-<name> /persist/vm-stores/<vm>/nix-store/store/<hash>-<name>
# "No such device or address" from cmp confirms a whiteout
```

**Fix.** Move the writable layer aside with the VM stopped. It holds only copies of runtime
store paths, not data, so this is safe. The VM rebuilds it on the next start:

```bash
sudo systemctl stop microvm@<vm>
cd /persist/vm-stores/<vm>
sudo mv nix-store nix-store.bak-$(date +%F)
sudo mkdir -p nix-store/store nix-store/work
sudo chmod 1775 nix-store/store && sudo chgrp nixbld nix-store/store
sudo systemctl start microvm@<vm>
```

Delete `nix-store.bak-*` once the VM has been stable. If the paths are missing on the **host**
instead (`ls /nix/store/<hash>-…` fails), the closure was never realised or was garbage
collected. Realise the VM's toplevel on the host and restart it.

**Symptom to avoid misreading:** `find -type c` output looks like a list of files. Those
lines are the whiteouts.

## `networking.networkmanager` quietly takes over a static NIC

**Symptom.** A VM with a static address (`systemd.network`, `DHCP = "no"`) answers ARP with the
wrong IP. The guest got a DHCP address from the pool, and the static address is unreachable.

**Cause.** fmf's common/hardware modules enable NetworkManager. On the VMs we checked,
`networking.networkmanager.enable` evaluated to `true` until forced off. NetworkManager then
DHCPs the NIC alongside networkd.

**Fix** for networkd-only guests:

```nix
networking.useNetworkd = true;
networking.useDHCP = false;
networking.networkmanager.enable = lib.mkForce false;
```

Check with `nix eval .#nixosConfigurations.<vm>.config.networking.networkmanager.enable`.

## A new user is silently added to `wheel`

**Symptom.** A user you meant as an ordinary account has passwordless sudo.

**Cause.** Snowfall Lib adds every user that has a `homes/<user>@<host>` configuration to
`wheel` (`snowfallorg.users.<name>.admin` defaults to `true`).

**Fix:**

```nix
snowfallorg.users.<name>.admin = false;
users.users.<name>.extraGroups = lib.mkForce ["users"];
```

Verify with `nix eval .#nixosConfigurations.<vm>.config.users.users.<name>.extraGroups` and
`config.security.sudo.wheelNeedsPassword`.

## A Vault sidecar fails on every boot

**Symptom.** `detsys-vaultAgent-copyNETRC` fails, or a service waits on it.

**Cause.** fmf's `nix` module renders the Nix netrc for every host with vault-agent. A guest
whose AppRole policy does not grant `secret/campground/netrc` cannot render it.

**Fix** in guests that do not need a private cache:

```nix
fmf.services.vault-agent.services.copyNETRC.enable = lib.mkForce false;
systemd.services.copyNETRC.enable = lib.mkForce false;
```

## Group IDs and users

fmf's `user` module defines the group `users` with gid `10000` (`GroupsIds`) on every host.
Creating another group with gid `10000` fails the evaluation with `UIDs and GIDs must be
unique!`. To share a uid with containers' PUID/PGID 10000, use the existing `users` group.

## Agent forwarding reaches every host

fmf's SSH client config sets `ForwardAgent yes` for every host in the flake. A sandbox guest
therefore receives your agent unless its sshd refuses it. Set:

```nix
services.openssh.settings = {
  AllowAgentForwarding = lib.mkForce false;
  AllowTcpForwarding = lib.mkForce false;
};
```

## Verifying a guest without booting it

- `nix eval .#nixosConfigurations.<vm>.config.system.build.toplevel.drvPath`: evaluates the whole
  configuration (catches duplicate definitions and assertions).
- `nix build --no-link .#nixosConfigurations.<vm>.config.system.build.toplevel`: builds it.
  Shellcheck runs on generated scripts during this build, and its findings fail it.
- Inspect generated units under `/nix/store/…-system/etc/systemd/system/` to see what actually
  runs, for example whether a sidecar is linked into `multi-user.target.wants`.
