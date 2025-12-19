{
  lib,
  config,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.fmf.apps.freerdp;
in {
  options.fmf.apps.freerdp = {enable = mkEnableOption "freerdp";};

  config = mkIf cfg.enable {home.packages = with pkgs; [freerdp];};
}
