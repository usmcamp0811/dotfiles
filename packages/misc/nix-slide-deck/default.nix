{ pkgs
, lib
, inputs
, ...
}:
with lib;
with lib.campground; let
  slides = mkSlide {
    inherit lib;
    stdenv = pkgs.stdenv;
    slidev = pkgs.campground.slidev;
    markdown = ./slides.md;
    themes = pkgs.campground.slidev-themes;
    customThemes = [ pkgs.campground.slidev-themes.neversink-theme pkgs.campground.slidev-themes.mokkapps-theme ];
    assets = [ ./assets ];
  };

  docker-slidev-dev = pkgs.dockerTools.streamLayeredImage {
    name = "slidev";
    tag = "latest";
    contents = [ pkgs.campground.slidev pkgs.campground.slidev-themes ];
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
    name = "serve-dev";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''

      [ -L themes ] || ln -s ${slides}/themes themes
      mkdir -p node_modules/.pnpm
      mkdir -p node_modules/@slidev
      mkdir -p node_modules/prism-theme-vars
      mkdir -p themes
      touch pnpm-lock.yaml


      ${pkgs.campground.slidev}/bin/slidev --remote

      # cleanup
      if [ -L ./themes ]; then rm ./themes; fi
      if [ -f ./pnpm-lock.yaml ]; then rm ./pnpm-lock.yaml; fi
      if [ -L node_modules/@slidev/theme-default ]; then rm node_modules/@slidev/theme-default; fi
      if [ -d node_modules/.pnpm ]; then rmdir node_modules/.pnpm; fi
      rmdir node_modules/@slidev 2>/dev/null || true
      rmdir node_modules/prism-theme-vars 2>/dev/null || true
      rmdir node_modules 2>/dev/null || true
    '';
  };
in
slides
  // {
  inherit serve;
  dev = serve-dev;
}
