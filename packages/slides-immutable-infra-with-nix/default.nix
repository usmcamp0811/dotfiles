{ lib, writeText, mkYarnPackage, substituteAll, gum, inputs, pkgs
, hosts ? { }, ... }:

let
  inherit (lib) mapAttrsToList concatStringsSep;
  inherit (lib.campground) override-meta;
  nix-slides = mkYarnPackage {
    version = "0.1.0";
    name = "nix-slides";
    src = ./immutable-infra-with-nix/.;
    packageJSON = ./immutable-infra-with-nix/package.json;
    yarnLock = ./immutable-infra-with-nix/yarn.lock;
    # doDist = true;
  buildPhase = ''
    export NODE_OPTIONS=--openssl-legacy-provider
    yarn 
  '';
  };
in
nix-slides
