{ lib, pkgs, ... }:
with lib;
with lib.fmf;
let
  example-chart = pkgs.stdenv.mkDerivation {
    name = "example-chart";
    src = ./.;
    installPhase = ''
      mkdir -p $out/src/chart
      cp -r $src/chart/* $out/src/chart
      mkdir -p $out/src/kubernetes
      cp -r $src/kubernetes/* $out/src/kubernetes
      mkdir -p $out/src/data
      cp -r $src/data/* $out/src/data
    '';
    meta = { mainProgram = "Campround"; };
  }; # // subCharts;
in
example-chart
