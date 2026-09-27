{lib, ...}: rec {
  ## Resolve one exact upstream package version through nixpkgs-multiverse
  ## (https://github.com/fzakaria/nixpkgs-multiverse) instead of adding a
  ## dedicated pinned `nixpkgs` flake input just to get that one version.
  ##
  ## ```nix
  ## package = lib.fmf.multiversePackage {
  ##   inherit inputs pkgs;
  ##   name = "traefik";
  ##   version = "3.7.13";
  ## };
  ## ```
  ##
  ## Only the single nixpkgs revision that shipped `name`@`version` is ever
  ## fetched and evaluated -- nixpkgs-multiverse resolves the version
  ## against a small pre-built JSON index first, so nothing else in the
  ## multiverse's history is touched. See nixpkgs-multiverse's own
  ## `versionDrv`/`version` implementation for the laziness guarantee this
  ## relies on.
  ##
  ## `inputs` must be the caller's own flake `inputs` (i.e. whatever a
  ## NixOS module's `inputs` special arg already is), carrying a
  ## `nixpkgs-multiverse` input -- this function does not read any
  ## `inputs` closed over by this lib file itself, since that would tie
  ## every caller to whichever flake happens to evaluate this file first.
  ##
  ## The target `system` is inferred from `pkgs.stdenv.hostPlatform.system`,
  ## never hardcoded, so this works on every system nixpkgs-multiverse
  ## indexes (currently x86_64-linux, aarch64-linux and aarch64-darwin).
  ##
  ## Architectural rule: this is an explicit, targeted escape hatch for a
  ## single leaf package/tool. It intentionally does NOT thread through a
  ## whole alternate package set the way `channels.unstable` /
  ## `channels.old-nixpkgs` do, and it does NOT re-apply this flake's own
  ## overlays (e.g. `overlays/overrides`'s Traefik plugin vendoring) to the
  ## package it returns. Reach for it for packages that can stand on their
  ## own historical dependency closure; do not reach for it for anything
  ## tightly coupled to the rest of the running system (kernel modules,
  ## libc, a matching server/extension pair, etc.) without first checking
  ## that closure is actually safe to mix in.
  ##
  ## Fails loudly (via nixpkgs-multiverse's own error, which lists every
  ## known version) if `name`@`version` was never shipped by any indexed
  ## nixpkgs revision, or if nixpkgs-multiverse has no index for the
  ## requested system.
  #@ { inputs: Flake-inputs, pkgs: Nixpkgs, name: String, version: String } -> Package
  multiversePackage = {
    inputs,
    pkgs,
    name,
    version,
  }: let
    multiverse =
      inputs.nixpkgs-multiverse
      or (throw ''
        lib.fmf.multiversePackage: `inputs.nixpkgs-multiverse` is not
        available. Add `nixpkgs-multiverse.url = "github:fzakaria/nixpkgs-multiverse";`
        to this flake's inputs.
      '');

    system = pkgs.stdenv.hostPlatform.system;

    mv =
      multiverse.multiverse.${system}
      or (throw ''
        lib.fmf.multiversePackage: nixpkgs-multiverse has no index for
        system "${system}" (requested while resolving ${name} ${version}).
      '');
  in
    # `mv.version` is nixpkgs-multiverse's own headline lookup: it throws a
    # clear error naming every known version of `name` when `version` was
    # never shipped, so that error is deliberately left to surface as-is
    # rather than duplicated here.
    mv.version name version;
}
