{ lib
, config
, pkgs
, ...
}:
with lib;
with lib.campground;
# mkRmfModuleFromPackage {
#   inherit config pkgs;
#   name = "example-flask-app";
#   pkg = pkgs.campground.example-rmf-flask-app;
# }
{
  options.campground.controls = lib.mkOption {
    type = lib.types.attrsOf lib.types.anything;
    default = { };
    description = "Holds active/inactive RMF control data across packages.";
  };
  config =
    mkIf cfg.enable { };
}
