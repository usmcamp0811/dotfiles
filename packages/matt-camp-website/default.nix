{ lib, writeText, mkYarnPackage, substituteAll, gum, inputs, pkgs
, hosts ? { }, ... }:

let
  inherit (lib) mapAttrsToList concatStringsSep;
  inherit (lib.campground) override-meta;
in
mkYarnPackage {
    name = "matt-com.com";
    src = ./.;
    packageJSON = ./package.json;
    yarnLock = ./yarn.lock;
    # NOTE: this is optional and generated dynamically if omitted
    yarnNix = ./yarn.nix;
}

