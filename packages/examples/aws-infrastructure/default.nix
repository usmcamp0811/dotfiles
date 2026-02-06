{ lib, pkgs, system, ... }:
with lib.fmf;
mkTerranixDerivation {
  inherit pkgs system;
  modules = [ ./example.nix ];
}
