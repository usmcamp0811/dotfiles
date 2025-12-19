{
  lib,
  config,
  ...
}: let
  inherit (lib) mkEnableOption mkIf;
  inherit (lib.fmf) enabled;

  cfg = config.fmf.cli.home-manager;
in {
  options.fmf.cli.home-manager = {
    enable = mkEnableOption "home-manager";
  };

  config = mkIf cfg.enable {programs.home-manager = enabled;};
}
