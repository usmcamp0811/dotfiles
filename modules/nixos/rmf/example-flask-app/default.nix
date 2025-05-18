{ lib
, config
, pkgs
, ...
}:
with lib;
with lib.campground;
mkRmfModuleFromPackage {
  inherit config;
  name = "example-flask-app";
  pkg = pkgs.campground.example-rmf-flask-app;
}
