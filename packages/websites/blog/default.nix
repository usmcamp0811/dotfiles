{ pkgs, lib, ... }:
let
  campground-blog = ./Campground/.;

  theme = pkgs.fetchFromGitHub {
    owner = "CaiJimmy";
    repo = "hugo-theme-stack";
    rev = "v3.27.0";
    # sha256 = "sha256-XlD469WutiSQ+P1pDFU66Skeo+7OPJVd7zpPxAZl09Q=";
    sha256 = "sha256-XlD469WutiSQ+P1pDFU66Skeo+7OPJVd7zpPxAZl09Q=";
  };

  hugo-server = pkgs.writeShellScriptBin "hugo-server" ''
    cd ${blog}
    umask 022
    tmp_dir=$(mktemp -d)
    cp -r ${blog}/* $tmp_dir
    chmod -R 777 $tmp_dir
    cd $tmp_dir
    echo $tmp_dir
    ${pkgs.hugo}/bin/hugo server
  '';

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
    passthru = {
      server = hugo-server;
      hugo = pkgs.hugo;
    };
  };
in blog
