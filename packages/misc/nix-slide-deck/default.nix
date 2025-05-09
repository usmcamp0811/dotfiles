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
      touch pnpm-lock.yaml
      touch node_modules/prism-theme-vars/base.css

      [ -L node_modules/@slidev/theme-default ] || ln -s ${slidev-themes}/packages/theme-default node_modules/@slidev/theme-default

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
serve // { dev = serve-dev; }
