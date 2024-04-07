{ lib, writeText, fetchFromGitHub, fetchYarnDeps, mkYarnPackage, substituteAll, gum, inputs, pkgs
, hosts ? { }, ... }:

let
  inherit (lib) mapAttrsToList concatStringsSep;
  inherit (lib.campground) override-meta;
  src = ./immutable-infra-with-nix/.;

  offlineCache = fetchYarnDeps {
    yarnLock = slidevSrc + "/yarn.lock";
    hash = "sha256-aK4P9KVu6KIzZmJca7sw0Vl1UM0RrSM9gGeFvs4KvSA=";
  };
  slidevSrc = fetchFromGitHub {
    owner = "slidevjs";
    repo = "slidev";
    rev = "v0.48.8"; # Use the latest release or commit hash
    sha256 = "sha256-yhm9ZQcQ/QXqAIb15VomX/gc287EoLuZzGYTUWNYj0o="; # Update this with the correct hash
  };
  nix-slides = mkYarnPackage {
    version = "0.1.0";
    name = "nix-slides";
    src = slidevSrc;
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
