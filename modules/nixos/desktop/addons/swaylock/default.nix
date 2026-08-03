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
    # Always install video background packages - they're small and optional to use
    environment.systemPackages = with pkgs; [
      swaylock-effects
      swaylock-plugin
      mpvpaper
    ];
    
    security.pam.services.swaylock = {};
    security.pam.services.swaylock-plugin = {};
  };
}
