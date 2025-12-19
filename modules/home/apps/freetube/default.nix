{ lib, config, ... }:
let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.fmf.apps.freetube;
in
{
  options.fmf.apps.freetube = {
    enable = mkEnableOption "freetube";
  };

  config = mkIf cfg.enable {
    programs.freetube = {
      enable = true;
    };
  };
}
