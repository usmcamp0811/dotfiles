# This overlay must be applied early via flake.nix's overlays list
# to be available during package evaluation
{ unstable, ... }:
final: prev: let
  system = prev.stdenv.hostPlatform.system;
in {
  nix-unstable = unstable.legacyPackages.${system};
}
