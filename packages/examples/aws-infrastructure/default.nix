{ lib, pkgs, inputs, system, ... }:
with lib;
with lib.campground;
mkTerranixDerivation {
  inherit pkgs system;
  extraArgs = { inherit pkgs; };
  modules = [ ./example.nix ];
}
