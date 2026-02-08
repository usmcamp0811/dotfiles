{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.fmf.tools.icehouse;

  inherit (lib) mkEnableOption mkIf;
in {
  options.fmf.tools.icehouse = {enable = mkEnableOption "Icehouse";};

  config = mkIf cfg.enable {
    environment.systemPackages = [pkgs.snowfallorg.icehouse];
  };
}
