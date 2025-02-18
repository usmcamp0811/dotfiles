{ lib, pkgs, ... }:
let

  hello-rust = pkgs.rustPlatform.buildRustPackage {
    pname = "hello-rust";
    version = "0.1.0";

    src = ./.;

    cargoLock = { lockFile = ./Cargo.lock; };

    nativeBuildInputs = [ pkgs.pkg-config ];
    buildInputs = [ ];
  };
in
hello-rust
