{ pkgs
, lib
, inputs
, ...
}:
with lib;
with lib.campground; let
  slidev-themes = pkgs.fetchFromGitHub {
    owner = "slidevjs";
    repo = "themes";
    rev = "v0.22.0";
    hash = "sha256-t6sg/nSbr2ytMHN1yuQy/kEDLyAYHXFVwcN1naeGhQc=";
  };
  slides = mkSlide {
    inherit lib;
    stdenv = pkgs.stdenv;
    slidev = pkgs.campground.slidev;
    markdown = ./slides.md;
    themes = slidev-themes;
    assets = [ ./assets ];
  };

  docker-slidev-dev = pkgs.dockerTools.streamLayeredImage {
    name = "slidev";
    tag = "latest";
    contents = [ pkgs.campground.slidev slidev-themes ];
    config = {
      Cmd = [ "${pkgs.slidev}/bin/slidev" "--remote" ];
      ExposedPorts = { "3030/tcp" = { }; };
    };
  };

  serve = pkgs.writeShellApplication {
    name = "serve";
    text = ''
      ${pkgs.python3}/bin/python3 -m http.server 8080 --directory ${slides}
    '';
  };
in
serve
