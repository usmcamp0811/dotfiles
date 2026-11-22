---
type: Guide
title: More than one user on a host
description: Add a second (or third) user to a system by adding another homes/<user>@<host> folder; what snowfall-lib creates for you, what fmf adds, and what you still set on the system.
tags: [users, home-manager, snowfall, guide]
---

# More than one user on a host

A system gets one user for every `homes/<arch>/<user>@<host>/default.nix` whose `<host>` matches the
system's name. No option has to be turned on and no snowfall-lib fork is needed: to give `example-system`
an `admin` account next to `example`, add a second home folder.

```text
homes/x86_64-linux/
  example@example-system/default.nix
  admin@example-system/default.nix     # new
systems/x86_64-linux/
  example-system/default.nix
```

The template `templates/example-downstream-flake` has exactly this layout (`nix flake init -t
gitlab:usmcamp0811/dotfiles/nixos#example-downstream-flake`). Campground's `krulak` is a real host set up
the same way (`mcamp@krulak` and `admin@krulak`).

## What you get from the home folder alone

For each matching home, snowfall-lib's system module:

* creates `users.users.<user>`: a normal user, group `users`, home `/home/<user>`, and `wheel` because
  `snowfallorg.users.<user>.admin` defaults to `true`;
* adds the folder as `home-manager.users.<user>`, with every fmf home module available, so
  `fmf.user.name` in that home defaults to `<user>`;
* lists the user in `snowfallorg.users`, which fmf's `nix` module adds to `nix.settings.allowed-users`. Home
  Manager's activation (`home-manager-<user>.service`) talks to the Nix daemon, and before this it failed
  with `cannot open connection to remote store 'daemon'` for every user except `fmf.user.name`.

Only `root`, `fmf.user.name` and `fmf.nix.additional-authorized-users` are `trusted-users`. An extra home
user may use the daemon but is not trusted.

## What you still set on the system

A Home Manager configuration cannot set NixOS options, and fmf's `fmf.user` (system side) describes one
user only: its shell, groups, UID, password and icon apply to that user and no other. Give every other user
what it needs in the system's `default.nix`:

```nix
{config, pkgs, ...}: {
  # Merged into the users.users.admin that snowfall-lib creates from homes/<arch>/admin@<host>.
  users.users.admin = {
    uid = 1001;                 # otherwise NixOS picks one
    shell = pkgs.zsh;           # otherwise bash
    extraGroups = ["docker"];   # wheel is already there
    openssh.authorizedKeys.keys = config.fmf.services.openssh.authorizedKeys;
    # hashedPasswordFile = "/persist/secrets/admin.passwd";  # no password is set by default
  };

  # Not an administrator: drop wheel.
  # snowfallorg.users.admin.admin = false;
}
```

In the user's home, set `fmf.user.uid` to the same UID if a home module reads it.

## Things that catch people out

* **No password.** The created user has none. On a host with an ephemeral root, a password set with
  `passwd` disappears at the next boot because `/etc/shadow` is not kept; set `hashedPasswordFile` or SSH
  keys in Nix.
* **UIDs.** A UID that NixOS picks is remembered in `/var/lib/nixos`. Keep that directory (impermanence
  hosts) or set `uid` yourself.
* **STIG presets replace `allowed-users`.** Crystal Forge's STIG `settings` module sets
  `nix.settings.allowed-users = ["root" "@wheel"]`, which replaces fmf's list. A user in `wheel` is still
  allowed; a user without `wheel` cannot use the daemon, so its Home Manager activation fails. Either keep
  the user in `wheel` or turn the preset off (`crystal-forge.stig-presets.off.enable = true`, as krulak
  does).
* **Files must be in git.** Snowfall-lib reads the flake source, so `git add` a new home folder before
  evaluating; an untracked folder is ignored and no user is created.
* **A standalone output too.** Each home folder is also a `homeConfigurations."<user>@<host>"` output.

## Checking it

```sh
nix eval --json .#nixosConfigurations.<host>.config.home-manager.users --apply builtins.attrNames
nix eval --json .#nixosConfigurations.<host>.config.users.users.admin \
  --apply 'u: {inherit (u) uid extraGroups home; shell = toString u.shell;}'
nix eval --json .#nixosConfigurations.<host>.config.nix.settings.allowed-users
```

After a switch, `systemctl status home-manager-admin` should be `active (exited)`.
