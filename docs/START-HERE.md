---
type: Guide
title: Welcome to the Campground - what it is and where to begin
description: What the fmf flake is and who it is for, four ways to use it (install NixOS, build your own flake on it, add a system, learn Nix), what to check before you copy anything, and a map for people and agents.
tags: [start, getting-started, overview]
---

# Welcome to the Campground

**fmf** is a NixOS flake that does two jobs at once.

1. **A module library.** More than a hundred service modules, plus desktop, user, network and security
   modules, all under one option namespace, `fmf.*`. Other flakes use it as an *upstream*: Campground, my
   own homelab, is a downstream of fmf.
2. **A worked example.** Real hosts, user homes, templates and runbooks that you can read, copy and
   change. Nothing here is hidden behind a private build.

I'm Matt Camp, and I maintain it. The source is at
[gitlab.com/usmcamp0811/dotfiles](https://gitlab.com/usmcamp0811/dotfiles) (branch `nixos`). It is
organised with [Snowfall Lib](https://snowfall.org/guides/lib/), which turns a directory layout into flake
outputs.

## Pick your path

| I want to... | Read | Time |
| --- | --- | --- |
| **Install NixOS** on a new machine from a flake | [Install NixOS on a new machine](INSTALL-NIXOS.md) | an evening |
| **Use fmf in my own flake** (fmf as upstream) | [Use fmf from your own flake](DOWNSTREAM-FLAKE.md) | 30 minutes |
| **Add another machine** to a flake that already uses fmf | [Add a system to your flake](NEW-SYSTEM.md) | 20 minutes |
| Give a machine **more than one user** | [More than one user on a host](MULTI-USER-HOSTS.md) | 10 minutes |
| **Understand** how the pieces fit | [How fmf is put together](HOW-FMF-WORKS.md) | 15 minutes |
| Find the command or file for **one specific job** | [Common tasks](COMMON-TASKS.md) | a lookup |
| Run **many hosts and MicroVMs** from records | [Getting started with the fleet](FLEET-GETTING-STARTED.md) | an hour |
| Provide **secrets** with Vault | [Vault runbook](VAULT-RUNBOOK.md) | an hour |

If you have never used Nix, read [New to Nix?](#new-to-nix) first.

## Before you copy anything

fmf is my own configuration, published as an example, and some of its defaults reflect that. Check these
before you deploy a host that uses it. [Use fmf from your own flake](DOWNSTREAM-FLAKE.md) shows the fixes.

* **My SSH keys are accepted by default.** Enabling `fmf.services.openssh` adds my public keys to the
  main user **and to `root`**. Replace the list with `lib.mkForce`, as the guides do.
* **The main user starts with the password `password`.** `fmf.user.initialPassword` defaults to it, and
  SSH accepts passwords unless you turn that off. Change it with `passwd` at first login and disable SSH
  password login.
* **Archetypes describe my own machines, not neutral defaults.** `barebones`, `server`, `workstation`,
  `laptop` and `gaming-platform` all switch on `fmf.suites.common`. On a downstream host that enables a
  Crystal Forge agent configured to connect to my server (`crystal-forge.aicampground.com`), a build-farm
  client, and my binary caches (`attic.aicampground.com`, `niks3.lan.aicampground.com`) as
  substituters, and it adds more of my SSH keys. **Do not use an archetype as it is.** The guides enable
  the individual modules they need, as the template does, and
  [How fmf is put together](HOW-FMF-WORKS.md#modules-suites-and-archetypes) lists what `common` turns on.
* **STIG hardening presets are on by default** for any host that imports the Crystal Forge modules
  (the downstream template imports them all). The pinned SSH preset currently fails evaluation, so the
  guides set `crystal-forge.stig-presets.off.enable = true`.
* **UEFI is assumed.** `fmf.system.boot` uses systemd-boot.
* **Example addresses only.** Anything in these docs on `192.168.50.0/24` is an example network, not a
  real one.

## New to Nix?

Read these in order. Each is short, and none assumes the one before it was fully understood.

1. [LevelUp Your Nix](LevelUp.md): install Nix, turn on flakes, start from a template, and the two parts
   of a `flake.nix`.
2. [How Nix works](nix-sequence-diagram.md): what happens between typing a command and getting a result.
3. [Loops in Nix](nix-loops.md): Nix has no loops; here is what you use instead.
4. The [NixOS manual](https://nixos.org/manual/nixos/stable/) for the module system, and
   [Home Manager](https://nix-community.github.io/home-manager/) for user environments.
5. Then [How fmf is put together](HOW-FMF-WORKS.md), which shows these ideas in this repository.

## Where things are

```text
systems/<arch>/<host>/          one directory per machine       -> nixosConfigurations.<host>
homes/<arch>/<user>@<host>/     one directory per user on host  -> home-manager for that user
modules/nixos|home|darwin/      the fmf.* options               -> nixosModules / homeModules
packages/  overlays/  lib/      packages, overlays, helpers     -> packages, overlays, lib.fmf
templates/                      starting points                 -> nix flake init -t
docs/ modules/ systems/         the documentation               -> this site
```

The full explanation is in [How fmf is put together](HOW-FMF-WORKS.md). Generated reference for every
`fmf.*` option is in the **options** section of this site.

## For agents

Read in this order, and stop when you have what you need.

1. [Common tasks](COMMON-TASKS.md) for the command and the files behind a job.
2. [How fmf is put together](HOW-FMF-WORKS.md) for the layout and the module pattern.
3. `modules/index.md` and `systems/index.md`, then the `README.md` beside the module or host you are
   changing. Do not grep the tree to find a module: the index lists every one with a description.
4. `docs/index.md` for guides, runbooks and designs.

Rules that apply everywhere:

* Verify by **evaluating**, not by reading: `nix eval .#nixosConfigurations.<host>.config.<option>`.
* Snowfall only sees files tracked by git: `git add` new files before evaluating.
* Public docs, examples and templates use the example network (`192.168.50.0/24`), never real addresses,
  and never contain secrets. Secrets come from Vault.
* `index.md` files are generated. Edit a document, then run `okf index --write docs`.
* A fix that belongs in a module belongs in fmf, not in a downstream flake.

## About these docs

The documentation is written as [Open Knowledge Format](OKF.md) bundles: Markdown with frontmatter, so a
person can read it in a browser and an agent can load it without special tooling. The page on
[how the bundles work](OKF.md) explains the trust levels shown on each page and how to add or check a
document.
