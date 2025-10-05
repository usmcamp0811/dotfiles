{
  lib,
  pkgs,
  ...
}: let
  versions = {
    "0.1.9" = {
      srcHash = "sha256-1dnfikwFuTPl6ojqoQt3S7wfdujEPYiCoh37aZMYLPc=";
      cargoHash = "sha256-KI2N6JidGz7lIkLtUG7EybdEZ8ZFiMcBUXKA1OnUfLE=";
    };
    # Add new versions here:
    # "0.2.0" = {
    #   srcHash = "sha256-...";
    #   cargoHash = "sha256-...";
    # };
  };

  # Set the default version here
  defaultVersion = "0.1.9";

  # Function to build a specific version
  mkReddix = version: let
    versionData = versions.${version};
  in
    pkgs.rustPlatform.buildRustPackage rec {
      pname = "reddix";
      inherit version;

      src = pkgs.fetchFromGitHub {
        owner = "ck-zhang";
        repo = "reddix";
        rev = "v${version}";
        hash = versionData.srcHash;
      };

      cargoHash = versionData.cargoHash;

      # Skip failing test
      checkFlags = [
        "--skip=config::tests::load_defaults_without_files"
      ];

      nativeBuildInputs = with pkgs; [pkg-config];
      buildInputs = with pkgs; [openssl];

      meta = with lib; {
        description = "A Redis clone implemented in Rust";
        homepage = "https://github.com/ck-zhang/reddix";
        license = licenses.mit;
        maintainers = [];
      };
    };

  # Build all versions
  allVersions = lib.mapAttrs (version: _: mkReddix version) versions;

  # Create v-prefixed versions for convenience
  vPrefixedVersions =
    lib.mapAttrs' (
      version: drv:
        lib.nameValuePair "v${version}" drv
    )
    allVersions;

  # Default package
  defaultPackage = mkReddix defaultVersion;
in
  defaultPackage
  // {
    passthru = allVersions // vPrefixedVersions;
  }
