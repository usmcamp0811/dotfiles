# tack (the pin manager for this repo) from the `tack` pin, instead of the older nixpkgs release.
# Every pkgs.tack user gets it: nixpkgs' programs.tack module, the flake-update alias, and
# downstream flakes (Campground) that reuse fmf's overlays.
{tack, ...}: final: prev: {
  tack = tack.packages.${prev.stdenv.hostPlatform.system}.tack;
}
