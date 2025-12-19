{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.services.busybox;
in {
  options.fmf.services.busybox = with types; {
    enable = mkBoolOpt false "Enable busybox;";
  };

  config =
    mkIf cfg.enable {environment.systemPackages = with pkgs; [busybox];};
}
