{
  lib,
  pkgs,
  ...
}: let
  versions = {
    "1.2.2" = {
      srcHash = "sha256-v2ZuqJiOFBAnBIlKk05E2XFxMhoIoNhAySSncGh8/AM=";
      cargoHash = "sha256-Yn333vSD1GmLpqvtzrSJliZmtEyaDw5HmCdqnxGw3MI=";
    };
  };

  defaultVersion = "1.2.2";

  mkReddix = version: let
    versionData = versions.${version};
  in
    pkgs.rustPlatform.buildRustPackage rec {
      pname = "weathr";
      inherit version;

      src = pkgs.fetchFromGitHub {
        owner = "Veirt";
        repo = "weathr";
        rev = "v${version}";
        hash = versionData.srcHash;
      };

      cargoHash = versionData.cargoHash;

      nativeBuildInputs = with pkgs; [pkg-config];
      buildInputs = with pkgs; [openssl cacert];
      doCheck = false;
      preCheck = ''
        export SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt
        export SSL_CERT_DIR=${pkgs.cacert}/etc/ssl/certs
      '';

      # Nix sandbox has no network: skip integration tests that hit api.open-meteo.com
      checkFlags = [
        "--skip=weather_client_integration_test"
      ];

      meta = with lib; {
        description = "A weather CLI written in Rust";
        homepage = "https://github.com/Veirt/weathr";
        license = licenses.mit;
        maintainers = [];
      };
    };

  allVersions = lib.mapAttrs (version: _: mkReddix version) versions;
  vPrefixedVersions = lib.mapAttrs' (version: drv: lib.nameValuePair "v${version}" drv) allVersions;
  defaultPackage = mkReddix defaultVersion;
in
  defaultPackage // {passthru = allVersions // vPrefixedVersions;}
