{ pkgs
, lib
, inputs
, ...
}:
with lib;
with lib.campground; let
  neversink-theme = buildTheme {
    inherit pkgs;
    pname = "slidev-theme-neversink";
    version = "0.3.6";
    src = pkgs.fetchFromGitHub {
      owner = "gureckis";
      repo = "slidev-theme-neversink";
      rev = "v0.3.6";
      hash = "sha256-JcdkZBcf059Pk5lqwGIlcTHmfIM54no98adeHe+TNBs=";
    };
    depsHash = "";
  };
  mokkapps-theme = buildTheme {
    inherit pkgs;
    pname = "slidev-theme-mokkapps";
    version = "0.1.0";
    src = pkgs.fetchFromGitHub {
      owner = "gureckis";
      repo = "slidev-theme-neversink";
      rev = "952996ba06cd27c0d1bab9625922723baa0271dd";
      hash = "sha256-m2RXHI+vvszYaDxO38mLdxMKZbtUgAMrdSJBCINgQSc=";
    };
    depsHash = "sha256-ZJh47LQamNh1kPd8c/JTlkcQp9k2MwKLkIw+f+102DE=";
  };
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
    customThemes = [ neversink-theme mokkapps-theme ];
    assets = [ ./assets ];
  };

  docker-slidev-dev = pkgs.dockerTools.streamLayeredImage {
    name = "slidev";
    tag = "latest";
    contents = [ pkgs.campground.slidev slidev-themes ];
    config = {
      Cmd = [ "${pkgs.campground.slidev}/bin/slidev" "--remote" ];
      ExposedPorts = { "3030/tcp" = { }; };
    };
  };

  serve = pkgs.writeShellApplication {
    name = "serve";
    text = ''
      ${pkgs.python3}/bin/python3 -m http.server 8080 --directory ${slides}
    '';
  };

  serve-dev = pkgs.writeShellApplication {
    # TODO: I dont like this it no work
    name = "serve-dev";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      [ -L ./themes ] || ln -s ${slidev-themes}/packages ./themes

      mkdir -p node_modules/.pnpm
      mkdir -p node_modules/@slidev
      mkdir -p node_modules/prism-theme-vars
      mkdir -p themes
      touch pnpm-lock.yaml
      touch node_modules/prism-theme-vars/base.css

      [ -L themes ] || ln -s ${slidev-themes}/themes themes

      ${pkgs.campground.slidev}/bin/slidev --remote

      # cleanup
      if [ -L ./themes ]; then rm ./themes; fi
      if [ -f ./pnpm-lock.yaml ]; then rm ./pnpm-lock.yaml; fi
      if [ -L node_modules/@slidev/theme-default ]; then rm node_modules/@slidev/theme-default; fi
      if [ -d node_modules/.pnpm ]; then rmdir node_modules/.pnpm; fi
      rmdir node_modules/@slidev 2>/dev/null || true
      rmdir node_modules 2>/dev/null || true
    '';
  };
in
slides
  // {
  inherit serve;
  dev = serve-dev;
}
