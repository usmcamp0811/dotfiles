{ lib, pkgs, inputs, ... }:
with lib;
with lib.fmf;
let
  inherit (lib) mapAttrsToList concatStringsSep;
  inherit (lib.fmf) override-meta;
  haskellEnv = pkgs.haskellPackages.ghcWithPackages (p: with p; [ ihaskell ]);
  jupyterConsole = createHaskellConsole "haskell-jupyter" "jupyter console" {
    inherit pkgs haskellEnv;
    kernelName = "haskell";
  };
in
haskellEnv // { jupyter = jupyterConsole; }
