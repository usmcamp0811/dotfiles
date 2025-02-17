{ lib, pkgs, inputs, ... }:
with lib;
with lib.campground;
let
  inherit (lib) mapAttrsToList concatStringsSep;
  inherit (lib.campground) override-meta;

in
createHaskellConsole "haskell-jupyter" "jupyter console" {
  inherit pkgs;
  haskellEnv = pkgs.haskellPackages.ghcWithPackages (p: with p; [ ihaskell ]);
  kernelName = "haskell";
}
