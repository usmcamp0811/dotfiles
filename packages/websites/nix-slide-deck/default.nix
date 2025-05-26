{ pkgs
, lib
, inputs
, ...
}:
with lib;
with lib.campground; let
  slidev = pkgs.campground.slidev.v0_50_0;
  stdenv = pkgs.stdenv;
  mac-builder = mkSlide {
    inherit lib stdenv slidev;
    markdown = ./mac-builder.md;
    urlBase = "/mac-builder/";
    themes = [ pkgs.campground.slidev-themes.neversink-theme ];
    slides = [ ./slides ];
    assets = [ ./assets ];
    meta = { title = "Remote Linux Builder on MacOS"; };
  };

  beyond-yaml = mkSlide {
    inherit lib stdenv slidev;
    markdown = ./beyond-yaml.md;
    urlBase = "/beyond-yaml/";
    themes = [ pkgs.campground.slidev-themes.neversink-theme ];
    slides = [ ./slides ];
    assets = [ ./assets ];
    meta = { title = "Beyond YAML: The Case for Nix as the Common Language of DevSecOps"; };
  };

  slides = mkSlide {
    inherit lib stdenv slidev;
    markdown = ./slides.md;
    urlBase = "/slides/";
    themes = [ pkgs.campground.slidev-themes.neversink-theme ];
    slides = [ ./slides ];
    assets = [ ./assets ];
    meta = { title = "A Nix Powered DevSecOps Revolution"; };
  };

  allSlides = {
    mac-builder = mac-builder;
    beyond-yaml = beyond-yaml;
    slides = slides;
  };

  index-page = makeIndexPage {
    inherit pkgs;
    slides = allSlides;
  };

  index-site =
    pkgs.runCommand "slide-index"
      {
        buildInputs = [ pkgs.coreutils ];
      } ''
      mkdir -p $out
      ${builtins.concatStringsSep "\n" (
        builtins.map (name: "cp -r ${getAttr name allSlides} $out/${name}") (builtins.attrNames allSlides)
      )}
      cp ${index-page} $out/index.html
    '';

  serve-index = pkgs.writeShellApplication {
    name = "serve-index";
    runtimeInputs = [ pkgs.python3 ];
    text = ''
      PORT="''${1:-8000}"
      cd ${index-site}
      echo "Serving on http://localhost:$PORT"
      ${pkgs.python3}/bin/python -m http.server "$PORT"
    '';
  };
in
index-site
  // {
  inherit mac-builder beyond-yaml slides serve-index;
  dev = serve-dev;
}
