<div align="center">

<h3>
  <img src="./camp-gumby.png" width="100" alt="Logo" style="border-radius: 50%; overflow: hidden;"/><br/>
  NixOS Config for <a href="https://matt-camp.com">Matt Camp</a>
  <img src="https://raw.githubusercontent.com/catppuccin/catppuccin/main/assets/misc/transparent.png" height="30" width="0px"/>
  <img referrerpolicy="no-referrer-when-downgrade" src="https://matomo.aicampground.com/matomo.php?idsite=3&amp;rec=1" style="border:0" alt="" />
</h3>

  <p>
    <a href="https://gitlab.com/usmcamp0811/dotfiles/-/commits/nixos">
        <img src="https://img.shields.io/badge/dynamic/json?color=363a4f&label=Stars&query=$.star_count&url=https%3A%2F%2Fgitlab.com%2Fapi%2Fv4%2Fprojects%2Fusmcamp0811%252Fdotfiles&style=for-the-badge">
    </a>
    <a href="https://gitlab.com/usmcamp0811/dotfiles/-/commits/nixos">
      <img src="https://img.shields.io/gitlab/last-commit/38220901?style=for-the-badge&color=rgb(54%2C%2058%2C%2079)">
    </a>
    <a href="https://nixos.wiki/wiki/Flakes" target="_blank">
      <img alt="Nix Flakes Ready" src="https://img.shields.io/static/v1?logo=nixos&logoColor=d8dee9&label=Nix%20Flakes&labelColor=5e81ac&message=Ready&color=d8dee9&style=for-the-badge">
    </a>
    <a href="https://github.com/snowfallorg/lib" target="_blank">
      <img alt="Built With Snowfall" src="https://img.shields.io/static/v1?logoColor=d8dee9&label=Built%20With&labelColor=5e81ac&message=Snowfall&color=d8dee9&style=for-the-badge">
    </a>
  </p>

</div>

Welcome to AI Campground, your gateway to my personalized Nix ecosystem. This repository is a comprehensive collection of my NixOS and generic Nix configurations, forming a cohesive, well-documented setup. I’m committed to providing detailed READMEs to share my journey, insights, and solutions to challenges encountered along the way.

## Documentation

Browse the rendered [Campground documentation](https://usmcamp0811.gitlab.io/dotfiles/campground/), including modules, systems, diagrams, search, and trust metadata. It is rebuilt and deployed to GitLab Pages on every commit.

## Getting Started

fmf (the Fleet Marine Force, after the author's Marine Corps background) is two things: a **library of NixOS modules** that other flakes build on, and a **worked example** of a
whole fleet you can read and copy. Start at the
[documentation site](https://usmcamp0811.gitlab.io/dotfiles/campground/); its front page sends you to the
right guide. The same guides are in [`docs/`](./docs/index.md) and read fine here.

| I want to... | Read |
| --- | --- |
| Understand what this is, and what to check first | [Start here](./docs/START-HERE.md) |
| Install NixOS on a new machine from a flake | [Install NixOS on a new machine](./docs/INSTALL-NIXOS.md) |
| Build my own flake on top of fmf | [Use fmf from your own flake](./docs/DOWNSTREAM-FLAKE.md) |
| Add another machine or another user | [Add a system](./docs/NEW-SYSTEM.md), [more than one user](./docs/MULTI-USER-HOSTS.md) |
| See how the pieces fit | [How fmf is put together](./docs/HOW-FMF-WORKS.md) |
| Look up a command or a file | [Common tasks](./docs/COMMON-TASKS.md) |
| Learn Nix first | [LevelUp Your Nix](./docs/LevelUp.md) |

> **Before you copy anything:** fmf is one person's configuration, published as an example. Its defaults
> accept the author's SSH keys and give the main user the password `password`, and its archetypes switch on
> services that are configured to connect to the author's servers.
> [Start here](./docs/START-HERE.md#before-you-copy-anything) lists what to change, and the tutorials do it
> for you.

You need [Nix with flakes enabled](./docs/LevelUp.md) and git. To start a flake of your own:

```bash
mkdir my-flake && cd my-flake
nix flake init -t gitlab:usmcamp0811/dotfiles/nixos#example-downstream-flake
git init && git add -A
```

To read or change fmf itself:

```bash
git clone https://gitlab.com/usmcamp0811/dotfiles.git
cd dotfiles
nix run .#campground      # the documentation site, offline, in your browser
```

## Features

Here's an overview of what my Nix configuration offers:

- **[Campground Nvim](https://gitlab.com/usmcamp0811/campground-nvim)**: I configured my Neovim config using [NixVim](https://github.com/nix-community/nixvim) and export it as a package.

- **Home Manager**: Manage your dotfiles, home environment, and user-specific configurations with Home Manager.

- **Hashicorp Vault**: Leveraging insights from [Jake Hamilton's dotfiles](https://github.com/jakehamilton/config), I've seamlessly integrated Vault Agent into my Nix configuration. This provides an exemplary secret management experience, eliminating the need to store sensitive information in git repositories or other insecure locations.

- **Automated Deploy**: Ability to automatically deploy all systems through Gitlab CICD or with `deploy --host <hostname> .#<hostname>`.

- **Git Pre-Commit Hooks**: Seamless integration of git hooks with Nix. To enable the hooks just activate the default shell. `nix develop`

- **System Observability & Monitoring**: Integrate Prometheus, Grafana, and Loki to achieve comprehensive monitoring of all systems, including Systemd services.

- **Terraform Modules**: Various modules for deploying infrastructure in the cloud with Terraform.

## Customization

Leveraging the Snowfall Org lib architecture, my Nix setup offers a streamlined and well-organized way to handle your Nix ecosystem. Here’s the breakdown:

- **Custom Library**: Located in the `lib/` folder, an optional custom library features a Nix function that utilizes `inputs`, `snowfall-inputs`, and `lib` to return an attribute set that merges with `lib`.

- **Hierarchical Directory Setup**: The `lib/` and `packages/` directories support a flexible, nestable folder structure. Each folder houses a Nix function designed to return an attribute set that blends seamlessly into `lib`, facilitating a modular configuration.

- **Package Layering**: Within the `packages/` folder, you have the option to define a collection of exportable packages. These packages are initialized using `callPackage` and should contain functions that accept an attribute set of packages and the essential `lib` to yield a derivation.

- **Configuration Modules**: The `modules/` folder allows you to set up NixOS modules tailored for different platforms like `nixos`, `darwin`, and `home`, making system configuration management more modular.

- **Personalized Overlays**: Use the `overlays/` directory for any custom overlays you may have. Each overlay function should accept three arguments: an attribute set based on your flake's inputs and a `channels` attribute that lists all accessible channels, the finalized `pkgs`, and their predecessors. This feature enhances package set customization.

- **System-Centric Configurations**: The `systems/` folder helps you organize your system setups by architecture and format, enabling configurations for multiple platforms like `x86_64-linux` or `aarch64-darwin`.

- **Home Environment Configs**: Similarly, the `homes/` folder arranges configurations by architecture, which is particularly handy for managing home environments via Nix.

This methodology fosters a user-friendly approach to Nix configuration, balancing both flexibility and modularity for better manageability.

## Credits

Inspiration and code snippets have been sourced from various corners of the internet. I'll endeavor to document these contributions whenever memory and circumstances permit.
