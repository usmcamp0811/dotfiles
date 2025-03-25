{ lib, pkgs, ... }:
let

  rust-db = pkgs.rustPlatform.buildRustPackage {
    pname = "rust-db";
    version = "0.1.0";

    src = ./.;

    cargoLock = { lockFile = ./Cargo.lock; };
    nativeBuildInputs = with pkgs; [ pkg-config ];
    buildInputs = with pkgs; [ openssl lalrpop ];
  };
in
rust-db
