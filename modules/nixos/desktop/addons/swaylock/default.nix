{
  options,
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.desktop.addons.swaylock;
in {
  options.fmf.desktop.addons.swaylock = with types; {
    enable = mkBoolOpt false "Swaylock fix so it works with pam";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [swaylock-effects];
    security.pam.services.swaylock = {};
  };
}
