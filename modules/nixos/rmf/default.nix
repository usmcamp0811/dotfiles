{ lib
, config
, ...
}:
with lib;
with lib.campground; let
  cfg = config.campground.controls;
in
{
  options.campground.controls = lib.mkOption {
    type = lib.types.attrsOf lib.types.anything;
    default = { };
    description = "Holds active/inactive RMF control data across packages.";
  };
  config =
    mkIf cfg.enable { };
}
