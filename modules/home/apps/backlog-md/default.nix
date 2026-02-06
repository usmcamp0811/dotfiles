{
  pkgs,
  lib,
  config,
  ...
}: let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.fmf.apps.backlog-md;
in {
  options.fmf.apps.backlog-md = {
    enable = mkEnableOption "backlog-md";
  };

  config = mkIf cfg.enable {
    home.packages = [
      pkgs.backlog-md
    ];
  };
}
