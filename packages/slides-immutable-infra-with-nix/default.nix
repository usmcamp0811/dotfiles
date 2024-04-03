{ lib, writeText, mkYarnPackage, substituteAll, gum, inputs, pkgs
, hosts ? { }, ... }:

let
  inherit (lib) mapAttrsToList concatStringsSep;
  inherit (lib.campground) override-meta;
  nix-slides = mkYarnPackage {
    name = "nix-slides";
    src = ./immutable-infra-with-nix/.;
    packageJSON = ./immutable-infra-with-nix/package.json;
    yarnLock = ./immutable-infra-with-nix/yarn.lock;
    # doDist = true;
  buildPhase = ''
    yarn build
  '';
  };
in
nix-slides
