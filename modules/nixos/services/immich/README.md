---
type: NixOS Module
title: fmf.services.immich
description: Wraps the upstream services.immich NixOS module with Postgres (via fmf.services.postgresql), Redis and machine learning defaults.
resource: ./default.nix
tags: [services, immich]
---

# fmf.services.immich

Wraps the upstream `services.immich` NixOS module with Postgres (via
`fmf.services.postgresql`), Redis and machine learning defaults.

## Choosing the Immich version

By default Immich comes from `pkgs.immich`, which this flake takes from the
`unstable` channel (`overlays/unstable-channel`). Moving it forward means
updating the whole `unstable` input, which also moves paperless, n8n, netbird,
etc.

To move only Immich, pin it:

```nix
fmf.services.immich.version = "3.3.3";
```

The package is resolved through
[nixpkgs-multiverse](https://github.com/fzakaria/nixpkgs-multiverse)
(`lib.fmf.multiversePackage`), so no extra nixpkgs input is needed. See
`docs/NIXPKGS-MULTIVERSE.md`.

Resolution order: `package` (explicit derivation) > `version` > `pkgs.immich`.

### Limits

- nixpkgs-multiverse indexes nixos channel tips, not `master`. A release is
  only pinnable after `nixos-unstable` has advanced past the nixpkgs commit
  that bumped it, and the `nixpkgs-multiverse` input has been updated.
  Before that, evaluation fails with
  `multiverse: no revision provides immich X.Y.Z` and lists known versions.
- The pinned package is built from its own nixpkgs revision. This flake's
  overlays are not applied to it.
- Check the Immich release notes before changing versions. The upstream module
  runs database migrations when the server starts.

Check what a host will use:

```console
nix eval --raw .#nixosConfigurations.<host>.config.services.immich.package.version
```
