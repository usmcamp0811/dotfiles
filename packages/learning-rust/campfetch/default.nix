{ lib
, pkgs
, ...
}:
let
  campfetch = pkgs.rustPlatform.buildRustPackage {
    pname = "campfetch";
    version = "0.1.0";

    src = ./.;

    cargoLock = { lockFile = ./Cargo.lock; };
    nativeBuildInputs = with pkgs; [ pkg-config ];
    buildInputs = with pkgs; [ openssl ];
  };
in
campfetch
