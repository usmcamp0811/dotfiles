{ lib, writeText, writeShellApplication, substituteAll, inputs, pkgs
, hosts ? { }, ... }:
let
  inherit (lib) mapAttrsToList concatStringsSep;
  inherit (lib.campground) override-meta;
  fuck-you-mac = pkgs.writeShellScriptBin "macsucks" ''
    echo "MAC IS STUPID!!"
  '';

in fuck-you-mac
