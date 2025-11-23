{
  lib,
  pkgs,
  ...
}: let
  pname = "jiq";
  owner = "bellicose100xp";
  repo = pname;
  description = "Interactive JSON query tool with real-time output";

  # Table of versions and hashes
  versions = {
    v2-5-0 = {
      version = "2.5.0";
      srcHash = "sha256-OjN5hFDKQjr7kSgpgvHiiexiabDgrykvyaXmL4rUUFc=";
      # if you haven't yet, set this to the 'got:' value from the vendor hash error
      cargoHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    };
  };

  mkJiq = {
    version,
    srcHash,
    cargoHash,
  }: let
    # Raw upstream source
    rawSrc = pkgs.fetchFromGitHub {
      inherit owner repo;
      rev = "v${version}";
      hash = srcHash;
    };

    # Wrap it with a Cargo.lock injected into the root
    src =
      pkgs.runCommand "${pname}-src-${version}" {
        inherit rawSrc;
        cargoLockFile = ./Cargo.lock;
      } ''
        mkdir -p "$out"
        cp -r "$rawSrc"/. "$out"/
        cp "$cargoLockFile" "$out/Cargo.lock"
      '';
  in
    pkgs.nix-unstable.rustPlatform.buildRustPackage {
      inherit pname version src cargoHash;

      # Point buildRustPackage at the lockfile in the staged src tree
      cargoLock = {
        lockFile = "${src}/Cargo.lock";
      };

      # Allow use of unstable features (let-chains) on this stable compiler
      RUSTC_BOOTSTRAP = 1;

      meta = {
        inherit description;
        homepage = "https://github.com/${owner}/${repo}";
        license = with lib.licenses; [mit asl20];
        platforms = lib.platforms.linux;
        mainProgram = "jiq";
      };
    };

  drvs = lib.mapAttrs (_: mkJiq) versions;

  latest = drvs.v2-5-0;
in
  latest // drvs
