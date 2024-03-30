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
website
# pkgs.stdenv.mkDerivation {
#   name = "example-ts-node";
#   version = "0.1.0";
#   src = website;
#   buildInputs = [ pkgs.nodejs pkgs.yarn website ];
#   buildPhase = ''
#     mkdir -p $out
#     # cp -r ${website.src} $out
#     cp -r ${website} $out
#     # yarn
#     # quasar build
#   '';
#   # installPhase = ''
#   #   # runHook preInstall
#   #   mkdir -p $out
#   #   cp ${website} $out/website
#   #   # cp -r node_modules $out/node_modules
#   #   # cp package.json $out/package.json
#   #   # cp -r dist $out/dist
#   #   # runHook postInstall
#   # '';
# }
