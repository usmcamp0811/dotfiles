{ lib
, config
, pkgs
, ...
}:
with lib;
with lib.fmf;
# mkRmfModuleFromPackage {
#   inherit config pkgs;
#   name = "example-flask-app";
#   pkg = pkgs.fmf.example-rmf-flask-app;
# }
{
  options.fmf.controls = lib.mkOption {
    type = lib.types.attrsOf lib.types.anything;
    default = { };
    description = "Holds active/inactive RMF control data across packages.";
  };
  config =
    mkIf cfg.enable { };
}
