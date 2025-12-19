{ lib
, config
, ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.controls;
in
{
  options.fmf.controls = lib.mkOption {
    type = lib.types.attrsOf lib.types.anything;
    default = { };
    description = "Holds active/inactive RMF control data across packages.";
  };
  config =
    mkIf cfg.enable { };
}
