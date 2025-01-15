{ lib, pkgs, system, ... }:
with lib.campground;
mkTerranixDerivation {
  inherit pkgs system;
  modules = [ ./example.nix ];
}
