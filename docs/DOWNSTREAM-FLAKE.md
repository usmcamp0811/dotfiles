---
type: Tutorial
title: Use fmf from your own flake
description: Start a flake of your own that uses fmf as its upstream - from the template, what each part of its flake.nix does, what to change before you deploy anything, how to follow or pin fmf, and how to add your own modules.
tags: [downstream, flake, template, tutorial, getting-started]
---

# Use fmf from your own flake

A **downstream flake** is your own repository that takes fmf's modules, overlays and Home Manager
configuration as an input and adds its own hosts on top. You keep your machines, secrets and settings in
your repository; fmf stays a library you follow or pin. My homelab, Campground, is built this
way.

You need [Nix with flakes enabled](LevelUp.md) and git.

> The template and the steps below were evaluated against the current fmf branch: the example host and
> a second host built from the steps in [Add a system to your flake](NEW-SYSTEM.md) both evaluate fully.
> Nothing was built or booted.

## 1. Start from the template

```bash
mkdir my-flake && cd my-flake
nix flake init -t gitlab:usmcamp0811/dotfiles/nixos#example-downstream-flake
git init && git add -A
```

`git add` matters: flakes ignore files that git does not track. You now have:

```text
flake.nix
homes/x86_64-linux/
  example@example-system/default.nix      the main user's Home Manager config
  admin@example-system/default.nix        a second user on the same host
systems/x86_64-linux/example-system/
  default.nix                             the host
  hardware.nix                            a placeholder: replace it
```

## 2. Read the `flake.nix`

It is short, and every line has a reason.

```nix
inputs = {
  unstable.url = "github:nixos/nixpkgs/nixos-unstable";
  nixpkgs.url = "github:nixos/nixpkgs/release-YY.MM";        # the release the template names

  fmf.url = "gitlab:usmcamp0811/dotfiles/nixos";

  snowfall-lib.url = "github:snowfallorg/lib";
  snowfall-lib.inputs.nixpkgs.follows = "nixpkgs";

  home-manager.url = "github:nix-community/home-manager/release-YY.MM";   # the same release
  home-manager.inputs.nixpkgs.follows = "nixpkgs";

  disko.url = "github:nix-community/disko";
  disko.inputs.nixpkgs.follows = "nixpkgs";
};
```

* `nixpkgs` and `home-manager` should be on the same release as each other and as fmf. Keep the
  `release-YY.MM` the template names; fmf's own `flake.nix` shows what fmf currently uses.
* `fmf` is the upstream. The `nixos` branch is where it moves.
* `snowfall-lib` reads your directory layout and produces the outputs
  (see [How fmf is put together](HOW-FMF-WORKS.md)).
* `disko` is only used if you let it manage disks, see [Install NixOS](INSTALL-NIXOS.md).

```nix
fmfInputs = inputs.fmf.inputs or {};

lib = inputs.snowfall-lib.mkLib {
  inherit inputs;
  src = ./.;
  snowfall = {
    meta = { name = "campground"; title = "Downstream Nix Config"; };
    namespace = "campground";
  };
};
```

`fmfInputs` is shorthand for fmf's own inputs: fmf's modules need modules from several of them, so you
import those too (below). The **namespace** is the prefix of options *you* write: a module of yours at
`modules/nixos/motd` would declare `config.campground.motd`. Change `campground` to your own name, here and
in `meta.name`. fmf's own options stay `fmf.*` and its helpers stay `lib.fmf`.

A simplified excerpt of the rest (the template has the full version):

```nix
lib.mkFlake {
  channels-config = { allowUnfree = true; /* ... */ };

  overlays = builtins.attrValues inputs.fmf.overlays;           # fmf's package overlays
  homes.modules = builtins.attrValues inputs.fmf.homeModules;   # fmf's Home Manager modules

  systems.modules.nixos = [
    inputs.home-manager.nixosModules.home-manager
    fmfInputs.stylix.nixosModules.stylix
    fmfInputs.nixos-boot.nixosModules.default
    # ...and the other modules fmf's own modules depend on
  ]
  ++ (lib.attrValues fmfInputs.crystal-forge.nixosModules)      # Crystal Forge's modules
  ++ (lib.attrValues inputs.fmf.nixosModules);                  # every fmf.* module

  deploy = lib.fmf.mkDeploy { inherit (inputs) self; };         # a deploy-rs node per host
};
```

`systems.modules.nixos` is the list that makes `fmf.*` options exist on your hosts. If you see
``The option `nixos-boot' does not exist`` (or `stylix`), a module that fmf's modules need is missing from
this list; copy the line from the template.

## 3. Make it yours, before anything else

The template is an example, so it contains someone else's details. Change these first.

1. **Delete `hardware.nix`'s placeholder.** It lists filesystems and a boot-partition UUID that are nobody's.
   Generate yours on the machine, see [Add a system to your flake](NEW-SYSTEM.md#2-the-hardware-file).
2. **Put your SSH key in.** In `systems/.../example-system/default.nix`, replace the placeholder under
   `fmf.services.openssh.authorizedKeys`. Keep `lib.mkForce`: without it fmf *adds* its defaults, which
   are my keys, and they are accepted for your user **and for root**.
3. **Rename the user and host.** The directory names `example@example-system` and `example-system`
   *are* the user and host names; the same names appear in `fmf.user.name`.
4. **Check the defaults that are not yours.** The template does not use an archetype for a reason, and
   sets `crystal-forge.stig-presets.off.enable = true`. Read
   [Start here](START-HERE.md#before-you-copy-anything) for the list: my keys, the initial password
   `password`, the Crystal Forge agent and caches that `fmf.suites.common` switches on.
5. **Change the example network and names** (`example.com`, `192.168.50.0/24`) if you use any.

Then check the result:

```bash
git add -A
nix eval --raw .#nixosConfigurations.example-system.config.system.build.toplevel.drvPath
nix eval --json .#nixosConfigurations.example-system.config.users.users.root.openssh.authorizedKeys.keys
```

The first evaluation downloads every input and can take several minutes. The second command must list
**only your key**.

## 4. Add machines

Every machine is a directory. Follow [Add a system to your flake](NEW-SYSTEM.md); to install one on blank
hardware, [Install NixOS on a new machine](INSTALL-NIXOS.md). A second user on a host is a second `homes/`
folder: [More than one user on a host](MULTI-USER-HOSTS.md).

## 5. Follow fmf, or pin it

`flake.lock` records the exact fmf commit you build with, so nothing changes until you ask:

```bash
nix flake update fmf        # take the newest fmf; review what changed, then rebuild
nix flake update            # update every input
git diff flake.lock         # what moved
```

To stay on a known commit regardless, put the commit in the URL:

```nix
fmf.url = "gitlab:usmcamp0811/dotfiles/<commit-sha>";
```

fmf is one person's configuration and its `nixos` branch changes often, so **pin when you deploy
something you rely on**, and update deliberately. Keep `nixpkgs` and `home-manager` on the release fmf
uses, or expect option names to differ.

## 6. Write your own modules

Anything under `modules/nixos/` is imported on every host, exactly like fmf's. A complete one, at
`modules/nixos/motd/default.nix`:

```nix
{
  config,
  lib,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.campground.motd;
in {
  options.campground.motd = {
    enable = mkBoolOpt false "Show a message when someone logs in.";
    message = mkOpt types.str "Welcome." "The message to show.";
  };

  config = mkIf cfg.enable {
    users.motd = cfg.message;
  };
}
```

Use it from any host:

```nix
campground.motd = {
  enable = true;
  message = "This machine is managed by Nix.";
};
```

`lib.fmf` (`mkOpt`, `mkBoolOpt`, `enabled`) is available in your modules, as it is in the template's
hosts and homes. `git add` the new file, or Nix will not see it. Modules for Home Manager go in
`modules/home/`.

## 7. When fmf is wrong

| You want to... | Do |
| --- | --- |
| Change one setting fmf makes | Set the option yourself; use `lib.mkForce` if fmf sets it with a higher priority |
| Remove something a suite turns on | Set it to `disabled`, or `lib.mkForce false` on the option |
| Fix a bug in an fmf module | Fix it in fmf and update your lock; a patch kept in your own flake drifts |

## Next

* [Add a system to your flake](NEW-SYSTEM.md)
* [Install NixOS on a new machine](INSTALL-NIXOS.md)
* [Common tasks](COMMON-TASKS.md)
