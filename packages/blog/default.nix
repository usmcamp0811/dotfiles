{ pkgs, lib, ... }:
let
  campground-blog = ./Campground/.;

  theme = pkgs.fetchFromGitHub {
    owner = "CaiJimmy";
    repo = "hugo-theme-stack";
    rev = "master";
    sha256 = "sha256-IMbEgE2+mCxwCpbvUnbnm7oED5+PkyRQlxbB+Oxl7yQ=";
  };

  blog = pkgs.stdenv.mkDerivation rec {
    name = "blog";
    version = "0.1.0";
    src = campground-blog;
    buildInputs = [ pkgs.hugo ];
    buildPhase = ''
      mkdir -p $out
      mkdir -p $out/public
      mkdir -p $out/themes/hugo-theme-stack
      cp -r ${campground-blog}/* $out
      cp -r ${theme}/* $out/themes/hugo-theme-stack
      cd $out
      ${pkgs.hugo}/bin/hugo
    '';

  };
in blog
