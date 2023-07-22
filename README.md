# README

I am converting my dotfiles over to Nix. As I learn things I'll add my notes here:

Basing them on [Snowfall Lib](https://github.com/snowfallorg/lib#lib)

```
flake-root/ 
│
│ Your Nix flake.
├─ flake.nix
│
│ An optional custom library.
├─ lib/
│  │
│  │ A Nix function called with `inputs`, `snowfall-inputs`, and `lib`.
│  │ The function should return an attribute set to merge with `lib`.
│  ├─ default.nix
│  │  
│  │ Any (nestable) directory name.
│  └─ **/
│     │
│     │ A Nix function called with `inputs`, `snowfall-inputs`, and `lib`.
│     │ The function should return an attribute set to merge with `lib`.
│     └─ default.nix
│
│ An optional set of packages to export.
├─ packages/
│  │
│  │ Any (nestable) directory name. The name of the directory will be the
│  │ name of the package.
│  └─ **/
│     │
│     │ A Nix package to be instantiated with `callPackage`. This file
│     │ should contain a function that takes an attribute set of packages
│     │ and *required* `lib` and returns a derivation.
│     └─ default.nix
│
│
├─ modules/ (optional modules)
│  │
│  │ Any (nestable) directory name. The name of the directory will be the
│  │ name of the module.
│  └─ **/
│     │
│     │ A NixOS module.
│     └─ default.nix
│
├─ overlays/ (optional overlays)
│  │
│  │ Any (nestable) directory name.
│  └─ **/
│     │
│     │ A custom overlay. This file should contain a function that takes three arguments:
│     │   - An attribute set of your flake's inputs and a `channels` attribute containing
│     │     all of your available channels (eg. nixpkgs, unstable).
│     │   - The final set of `pkgs`.
│     │   - The previous set of `pkgs`.
│     │
│     │ This function should return an attribute set to merge onto `pkgs`.
│     └─ default.nix
│
├─ systems/ (optional system configurations)
│  │
│  │ A directory named after the `system` type that will be used for all machines within.
│  │
│  │ The architecture is any supported architecture of NixPkgs, for example:
│  │  - x86_64
│  │  - aarch64
│  │  - i686
│  │
│  │ The format is any supported NixPkgs format *or* a format provided by either nix-darwin
│  │ or nixos-generators. However, in order to build systems with nix-darwin or nixos-generators,
│  │ you must add `darwin` and `nixos-generators` inputs to your flake respectively. Here
│  │ are some example formats:
│  │  - linux
│  │  - darwin
│  │  - iso
│  │  - install-iso
│  │  - do
│  │  - vmware
│  │
│  │ With the architecture and format together (joined by a hyphen), you get the name of the
│  │ directory for the system type.
│  └─ <architecture>-<format>/
│     │
│     │ A directory that contains a single system's configuration. The directory name
│     │ will be the name of the system.
│     └─ <system-name>/
│        │
│        │ A NixOS module for your system's configuration.
│        └─ default.nix
```


## Services that Require Secrets (wip)

I am using Vault to store secrets. I am currently working with the pattern of creating services and if they require secrets I
add the `vault-agent` service that will get the secret and patch the service all in the same file. I then have options
to allow specifying the `role-id`, `secret-id` and `vault.address` as part of the service options, defaults are set
to the "system" values that get set in the system config file. This should limit the need to repeat yourself on multiple systems.
See my `SECRETS.md` for more details. I will update this to be more clear later... maybe... we will see.. ¯\_(ツ)_/¯
