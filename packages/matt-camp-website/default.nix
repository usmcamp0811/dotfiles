{
  lib,
  writeText,
  mkYarnPackage,
  substituteAll,
  gum,
  inputs,
  pkgs,
  hosts ? {},
  ...
}: let
  inherit (lib) mapAttrsToList concatStringsSep;
  inherit (lib.campground) override-meta;
  matt-camp-website = mkYarnPackage {
    name = "matt-com.com";
    src = ./.;
    packageJSON = ./package.json;
    yarnLock = ./yarn.lock;
    doDist = true;
    buildPhase = ''
      export NODE_OPTIONS=--openssl-legacy-provider
      yarn build
    '';
  };
in
  matt-camp-website
