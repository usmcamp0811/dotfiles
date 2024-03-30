{ lib, writeText, mkYarnPackage, substituteAll, gum, inputs, pkgs
, hosts ? { }, ... }:

let
  inherit (lib) mapAttrsToList concatStringsSep;
  inherit (lib.campground) override-meta;
  website = mkYarnPackage {
    name = "matt-com.com";
    src = ./.;
    packageJSON = ./package.json;
    yarnLock = ./yarn.lock;
    yarnNix = ./yarn.nix;
    doDist = true;
  };
in
pkgs.stdenv.mkDerivation {
  name = "example-ts-node";
  version = "0.1.0";
  src = website;
  buildInputs = [ pkgs.nodejs pkgs.yarn website ];
  buildPhase = ''
    # each phase has pre/postHooks. When you make your own phase be sure to still call the hooks
    yarn
    quasar build
  '';
  installPhase = ''
    runHook preInstall
    cp -r node_modules $out/node_modules
    cp package.json $out/package.json
    cp -r dist $out/dist
    runHook postInstall
  '';
}
