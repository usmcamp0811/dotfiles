---
type: Reference
title: Common tasks
description: One place to look up the command and the files for a job - build or check a host, read an option, find a module, deploy, roll back, update inputs, add a host, a user or a module, and check the documentation - with the rules that stop mistakes.
tags: [reference, commands, agents, getting-started]
---

# Common tasks

The command and the files behind each job, for people and for agents. Commands run from the root of the
flake. `<host>` is a directory name under `systems/<arch>/`. New to all this? Read
[Start here](START-HERE.md) first.

## Rules that apply to everything

* **Flakes only see files git tracks.** `git add` anything new before you evaluate or build.
* **Evaluate to check, do not guess.** Reading a module does not tell you what a host ends up with;
  `nix eval` does.
* **Example addresses only** in anything public: `192.168.50.0/24`, `example.com`. No real addresses,
  names or secrets in fmf's docs, examples or templates. Secrets come from Vault.
* **A fix to a module belongs in fmf**, not in a downstream flake.
* **Do not run store paths you did not build on purpose.** A generated disko script erases disks.

## Look something up

### Find a module or an option

Read `modules/index.md` (every module, with a description), then the `README.md` beside the module. The
generated **options** section of the documentation site lists every `fmf.*` option with its type.

To list options from a real host:

```bash
# Which fmf.services options exist
nix eval --json .#nixosConfigurations.<host>.options.fmf.services --apply builtins.attrNames
# What one option is for
nix eval --json .#nixosConfigurations.<host>.options.fmf.services.docker.enable.description
```

### Read what a host actually ends up with

```bash
nix eval --json .#nixosConfigurations.<host>.config.<option.path>
nix eval --json .#nixosConfigurations.<host>.config.home-manager.users --apply builtins.attrNames
nix eval --json .#nixosConfigurations.<host>.config.users.users.root.openssh.authorizedKeys.keys
```

### List what the flake offers

```bash
nix flake show                                  # all outputs (slow on this flake)
nix eval --json .#nixosConfigurations --apply builtins.attrNames    # the hosts
nix eval --json .#templates --apply builtins.attrNames              # the templates
```

## Build and check

```bash
# Evaluate only: quick, catches most mistakes, changes nothing
nix eval --raw .#nixosConfigurations.<host>.config.system.build.toplevel.drvPath

# Build the system: changes nothing on any machine
nix build .#nixosConfigurations.<host>.config.system.build.toplevel
```

An `error: ... option ... does not exist` almost always means a module is not imported (see
[Use fmf from your own flake](DOWNSTREAM-FLAKE.md#2-read-the-flakenix)) or the option name is wrong.

## Deploy a host

| From | Command |
| --- | --- |
| the machine itself | `sudo nixos-rebuild switch --flake .#<host>` |
| another computer, over SSH | `nixos-rebuild switch --flake .#<host> --target-host root@<address>` |
| another computer, with deploy-rs | `deploy .#<host>` |
| deploy-rs, to an address that is not the host name | `deploy --hostname <address> --skip-checks .#<host>` |
| deploy-rs, activate on next boot only | `deploy --boot .#<host>` |

`deploy` takes its nodes from `lib.fmf.mkDeploy`: one node per host, named after it, logging in as `root`.
`switch` activates now; `boot` makes it the default for the next boot; `test` activates without making it
permanent.

### Roll back

```bash
sudo nixos-rebuild switch --rollback      # go back one generation
```

or choose an older generation in the boot menu. Older generations stay until you remove them
(`sudo nix-collect-garbage -d` removes all but the current one) or an automatic clean-up does.

## Update

```bash
nix flake update fmf        # one input
nix flake update            # all inputs
git diff flake.lock         # what moved
```

Update, build, then deploy; never update and deploy in one step on a machine you cannot reach.

## Add things

| To add... | Do | Files |
| --- | --- | --- |
| a host | [Add a system to your flake](NEW-SYSTEM.md) | `systems/<arch>/<host>/` |
| a host on blank hardware | [Install NixOS on a new machine](INSTALL-NIXOS.md) | adds `disko.nix` |
| a user on a host | [More than one user on a host](MULTI-USER-HOSTS.md) | `homes/<arch>/<user>@<host>/` |
| a module | [Use fmf from your own flake](DOWNSTREAM-FLAKE.md#6-write-your-own-modules) | `modules/nixos/<area>/<name>/default.nix` |
| a flake of your own | [Use fmf from your own flake](DOWNSTREAM-FLAKE.md) | `nix flake init -t ...#example-downstream-flake` |
| a fleet of hosts and MicroVMs | [Getting started with the fleet](FLEET-GETTING-STARTED.md) | `host.nix` per host |
| Vault secrets for a host | [Vault runbook](VAULT-RUNBOOK.md) | |

### Start a new project from a template

```bash
nix flake init -t gitlab:usmcamp0811/dotfiles/nixos#<template>
```

The templates are `basic`, `basic-flake-system`, `example-downstream-flake`, `flink-job`, `julia-project`,
`new-azure-vm`, `new-system`, `python-package-with-tests`, `shell-container`, `simple-rust-package`,
`slidev` and `snowfall`. For a NixOS flake use `example-downstream-flake`.

## Write and check documentation

The `docs/`, `modules/` and `systems/` directories are [Open Knowledge Format](OKF.md) bundles.

```bash
nix run .#okf -- check docs modules systems       # errors fail, warnings are advice
nix run .#okf -- index --write docs               # regenerate docs/index.md after adding or retitling
nix build .#checks.x86_64-linux.okf               # the full check, including the website
nix run .#campground                              # read the rendered site in a browser
```

* A new document needs frontmatter with at least `type`; give it a `title` and a one-sentence
  `description`, which is copied into the index.
* `index.md` files are generated: never edit one by hand.
* Add a line to `docs/log.md` for a change a reader would want to know about.
* Never add `verified:` unless a person reviewed the page.

## Format and hooks

The repository's pre-commit hook formats Nix with `nixpkgs-fmt`. Enter the development shell to install
the hooks, then commit as usual:

```bash
nix develop
```

## When a command fails

| You see | Meaning |
| --- | --- |
| `error: path '/nix/store/...-source/<file you created>' does not exist` | The file is not tracked by git, so it is missing from the copy Nix evaluates. `git add` it. |
| `The option '...' does not exist` | The module is not imported, or the option is misspelt. Check the name against the options reference. |
| `The option '...' has conflicting definition values` | Two modules set it differently. Set yours with `lib.mkForce`, or remove the other. |
| `Failed assertions` | A module refused the configuration. The message names the file and the fix. |
| `hash mismatch in fixed-output derivation` | A download changed. Update the hash from the `got:` line. |
