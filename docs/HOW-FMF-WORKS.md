---
type: Overview
title: How fmf is put together
description: The layers (nixpkgs, modules, suites, archetypes, hosts, homes), the Snowfall directory layout, the one pattern every module follows, and how a host is assembled from files. Read this before changing anything.
tags: [start, architecture, snowfall, modules]
---

# How fmf is put together

This page explains the ideas once, so the tutorials can stay short. If you want to *do* something, go
to [Start here](START-HERE.md); come back when a word in a guide is unfamiliar.

## The layers

```text
nixpkgs + NixOS             packages and the stock NixOS options
  fmf modules               fmf.* options: one feature each (a service, a tool, a desktop)
    suites                  fmf.suites.*: groups of modules that belong together
      archetypes            fmf.archetypes.*: a machine role (barebones, server, laptop, ...)
        your host           systems/<arch>/<host>: which archetype, which settings, which disks
          your homes        homes/<arch>/<user>@<host>: what each user's environment contains
```

Each layer only switches on the layer below it, and almost every module is off until a host enables it.
The exceptions are the foundations every host gets: the main user and its shell (`fmf.user`), Home
Manager (`fmf.home`) and the Nix settings (`fmf.nix`, on by default).

## The directory layout

fmf uses [Snowfall Lib](https://snowfall.org/guides/lib/), which reads a fixed directory layout and
produces the flake outputs from it. You never write `nixosConfigurations.myhost = ...` by hand.

| Directory | What goes in it | Becomes |
| --- | --- | --- |
| `systems/<arch>/<host>/default.nix` | A machine: `x86_64-linux`, `aarch64-linux`, ... | `nixosConfigurations.<host>` |
| `systems/<arch>-<format>/<name>/` | An image: `x86_64-iso`, `x86_64-vm`, `x86_64-azure`, ... | `isoConfigurations.<name>`, ... |
| `homes/<arch>/<user>@<host>/default.nix` | One user on one host | that user's Home Manager config, and a `homeConfigurations` output |
| `modules/nixos/<area>/<name>/default.nix` | A NixOS module | imported on **every** host |
| `modules/home/...`, `modules/darwin/...` | Home Manager and macOS modules | imported for every home / Mac |
| `packages/<name>/default.nix` | A package or script | `packages.<system>.<name>` |
| `overlays/`, `lib/`, `shells/` | Overlays, helper functions, dev shells | `overlays`, `lib.fmf.*`, `devShells` |
| `templates/` | Starting points (declared in `flake.nix`) | `nix flake init -t` |
| `checks/` | Tests | `checks.<system>.<name>` |

Two names matter. The **namespace** is `fmf` (the Fleet Marine Force; see [Start here](START-HERE.md)): it
is the prefix of every option (`fmf.services.openssh`) and of the helper library (`lib.fmf`). A downstream flake picks its own namespace for its own modules and
still uses fmf's. The **architecture directory** decides the system type, so a host that exists for two
architectures needs two directories.

## The one pattern every module follows

Every file under `modules/nixos` has the same shape: declare an option, then do something only if it is
on. This is the whole `barebones` archetype:

```nix
{ options, config, lib, ... }:
with lib;
with lib.fmf; let
  cfg = config.fmf.archetypes.barebones;
in
{
  options.fmf.archetypes.barebones = with types; {
    enable = mkBoolOpt false "Whether or not to enable the barebones archetype.";
  };

  config = mkIf cfg.enable { fmf = { suites = { common = enabled; }; }; };
}
```

`lib.fmf` is fmf's own helper library (`lib/module/default.nix`):

| Helper | Meaning |
| --- | --- |
| `mkOpt type default "description"` | Declare an option |
| `mkBoolOpt default "description"` | Declare a boolean option |
| `enabled` | The attribute set `{ enable = true; }`, so `fmf.tools.git = enabled;` |
| `disabled` | `{ enable = false; }` |

Because every module is imported everywhere, **adding a feature is adding a directory**, and
**using a feature is setting its option**. To find what is available, read `modules/index.md` or the
generated **options** section of this site; do not guess an option name.

## Modules, suites and archetypes

* A **module** is one feature: `fmf.services.openssh`, `fmf.tools.git`, `fmf.system.zfs`.
* A **suite** switches on a group of modules: `fmf.suites.common`, `desktop`, `development`,
  `observability`, `microvm-host` and others (`modules/nixos/suites`).
* An **archetype** is a machine role that switches on suites and some services: `barebones`,
  `basic-pi`, `server`, `workstation`, `laptop` and `gaming-platform` (`modules/nixos/archetypes`).

The name `barebones` is misleading: it turns on `suites.common`, and `common` is my own baseline
for my machines. It enables, among other things:

* the **Crystal Forge** agent, configured to connect to my server;
* the **build-farm** client (`nix-grpc-store`);
* my **binary caches** (`campground`, `niks3`) alongside the public ones;
* OpenSSH with **my public keys**, git, audio, networking, fonts, locale and the boot module.

`server`, `workstation`, `laptop` and `gaming-platform` include `common` too. That suits me, and
nobody else. **For a host of your own, enable the individual modules you want**, as the template's
`example-system` and the tutorials do, and read an archetype's file before using it. See
[Start here](START-HERE.md#before-you-copy-anything) for the full list of defaults to check.

## How a host is assembled

A host is a directory. This is the template's example host, the smallest useful one:

```text
systems/x86_64-linux/example-system/
  default.nix     what this machine is: archetype, user, services, settings
  hardware.nix    what this machine physically is (generated, not hand-written)
  disko.nix       (optional) how its disks are laid out; see Install NixOS
homes/x86_64-linux/
  example@example-system/default.nix     the main user's environment
  admin@example-system/default.nix       a second user, if you want one
```

* **`default.nix`** enables fmf modules and sets NixOS options side by side. `fmf.user` describes the
  **main user** (name, groups, UID); `fmf.services.openssh`, `fmf.nix` and so on configure the services.
  Plain NixOS options such as `networking.hostName` and `system.stateVersion` work as usual.
* **`hardware.nix`** is produced by `nixos-generate-config`. Never write it by hand.
* **`homes/<user>@<host>`** is a Home Manager configuration, and is how you add users: one folder per user
  per host. See [More than one user on a host](MULTI-USER-HOSTS.md).
* A host with no `homes/` folder still works: fmf's own module gives `fmf.user` a minimal Home Manager
  configuration.

## Building and changing a system

```bash
nix build .#nixosConfigurations.<host>.config.system.build.toplevel    # build, change nothing
sudo nixos-rebuild switch --flake .#<host>                              # build and activate here
deploy .#<host>                                                         # push to another machine
```

`deploy` is [deploy-rs](https://github.com/serokell/deploy-rs); fmf's `lib.fmf.mkDeploy` creates a node
for every host, named after it and connected as `root`. See [Common tasks](COMMON-TASKS.md) for more.

## What is in `flake.nix`

The inputs worth knowing: `nixpkgs` (a stable release) and `unstable`, `home-manager`, `snowfall-lib`,
`disko` (disk layouts), `impermanence` (a wiped root), `microvm` (MicroVMs), `stylix` (theming),
`vault-service` (secrets), `deploy-rs` and `crystal-forge` (STIG presets and CVE tracking). A downstream
flake reuses fmf's overlays, Home Manager modules and NixOS modules; the
[downstream tutorial](DOWNSTREAM-FLAKE.md) shows the wiring.

## Where the documentation lives

| Bundle | Holds | Start at |
| --- | --- | --- |
| `docs/` | Guides, tutorials, runbooks, designs | [`docs/index.md`](index.md) |
| `modules/` | One README per module, next to its `default.nix` | `modules/index.md` |
| `systems/` | One README per host | `systems/index.md` |
| options (generated) | Every `fmf.*` option, from the module code | the **options** section of the site |

The bundles are in [Open Knowledge Format](OKF.md).
