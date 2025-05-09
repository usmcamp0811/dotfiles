{ pkgs
, lib
, inputs
, ...
}:
with lib;
with lib.campground; let
  slidev-themes = pkgs.${system}.fetchFromGitHub {
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
    assets = [ ./src/assets ];
  };
in
slides
