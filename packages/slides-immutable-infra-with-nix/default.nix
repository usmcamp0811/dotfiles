{
  lib,
  writeText,
  fetchYarnDeps,
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
  src = ./immutable-infra-with-nix/.;
  nix-slides = mkYarnPackage {
    version = "0.1.0";
    name = "nix-slides";
    src = src;
    offlineCache = fetchYarnDeps {
      yarnLock = src + "/yarn.lock";
      hash = "sha256-aK4P9KVu6KIzZmJca7sw0Vl1UM0RrSM9gGeFvs4KvSA=";
    };
    # packageJSON = ./immutable-infra-with-nix/package.json;
    # yarnLock = ./immutable-infra-with-nix/yarn.lock;
    # yarnNix = offlineCache;
    # doDist = false;
    preInstall = "yarn --offline run build";
    # buildPhase = ''
    #   export HOME=$TMPDIR
    #   yarn build --offline
    # '';
  };
in
  nix-slides
# offlineCache

