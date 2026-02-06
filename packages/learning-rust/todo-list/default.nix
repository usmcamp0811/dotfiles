{ lib, pkgs, ... }:
let

  todo-list = pkgs.rustPlatform.buildRustPackage {
    pname = "todo-list";
    version = "0.1.0";

    src = ./.;

    cargoLock = { lockFile = ./Cargo.lock; };

    nativeBuildInputs = [ pkgs.pkg-config ];
    buildInputs = [ ];
  };
in todo-list
