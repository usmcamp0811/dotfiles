{ lib, pkgs, ... }:
let

  webb-app = pkgs.rustPlatform.buildRustPackage {
    pname = "webb-app";
    version = "0.1.0";

    src = ./.;

    cargoLock = { lockFile = ./Cargo.lock; };

    nativeBuildInputs = [ pkgs.pkg-config ];
    buildInputs = [ ];
  };
in
webb-app
