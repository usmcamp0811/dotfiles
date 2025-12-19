{
  lib,
  config,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.fmf.apps.zoom;
in {
  options.fmf.apps.zoom = {enable = mkEnableOption "zoom";};

  config = mkIf cfg.enable {home.packages = with pkgs; [zoom-us];};
}
