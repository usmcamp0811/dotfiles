{ lib, pkgs, ... }:
let

  oci-interface = pkgs.rustPlatform.buildRustPackage {
    pname = "oci-interface";
    version = "0.1.0";

    src = ./.;

    cargoLock = { lockFile = ./Cargo.lock; };
    nativeBuildInputs = with pkgs; [ pkg-config ];
    buildInputs = with pkgs; [ openssl ];
  };
in
oci-interface
