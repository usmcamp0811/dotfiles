{ lib, pkgs, ... }:
let
  web-app = pkgs.rustPlatform.buildRustPackage {
    pname = "example-rust-web-app";
    version = "0.1.0";
    src = ./.;
    cargoLock.lockFile = ./Cargo.lock;

    nativeBuildInputs = [
      pkgs.lld
      pkgs.openssl
      pkgs.pkg-config
      pkgs.dioxus-cli
      pkgs.wasm-bindgen-cli
    ];

    buildInputs = [ pkgs.openssl.dev pkgs.zlib ];
    buildPhase = ''
      export XDG_DATA_HOME=$PWD
      mkdir -p $XDG_DATA_HOME/dioxus/wasm-bindgen
      ln -s ${pkgs.wasm-bindgen-cli}/bin/wasm-bindgen $XDG_DATA_HOME/dioxus/wasm-bindgen/wasm-bindgen-0.2.100

      dx bundle --platform web 
    '';

    installPhase = ''
      mkdir -p $out
      cp -r target/dx/*/release/web/public $out/public
    '';
  };
in
web-app
