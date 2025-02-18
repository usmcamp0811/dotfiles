{ lib, pkgs, ... }:
let

  hello-zig = pkgs.stdenv.mkDerivation {
    pname = "hello-zig";
    version = "0.1.0";

    src = ./.;
    buildInputs = [ pkgs.zig ];
    buildPhase = "zig build";
    installPhase = "mkdir -p $out/bin; cp zig-out/bin/* $out/bin/";
  };
in
hello-zig
