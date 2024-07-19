{ pkgs, lib, ... }:
let
  blog = pkgs.stdenv.mkDerivation rec {
    name = "blog";
    version = "0.1.0";
    src = ./.;
    buildInputs = [ pkgs.hugo ];

    installPhase = "";
  };
in blog
