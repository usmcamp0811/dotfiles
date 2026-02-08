{ lib, pkgs, ... }:
let

  list-comp = pkgs.rustPlatform.buildRustPackage {
    pname = "list-comprehension";
    version = "0.1.0";

    src = ./.;

    cargoLock = { lockFile = ./Cargo.lock; };
    nativeBuildInputs = with pkgs; [ pkg-config ];
    buildInputs = with pkgs; [ openssl ];
  };
in
list-comp
