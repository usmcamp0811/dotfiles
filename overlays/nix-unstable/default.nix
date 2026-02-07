# This overlay must be applied early via flake.nix's overlays list
# to be available during package evaluation
{ unstable, ... }:
final: prev: {
  nix-unstable = unstable.legacyPackages.${prev.system};
}
