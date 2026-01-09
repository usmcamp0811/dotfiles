{
  options,
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.system.plymouth;
in {
  options.fmf.system.plymouth = with types; {
    enable = mkBoolOpt false "Whether to enable Plymouth boot splash screen.";

    theme = mkOpt str "breeze" ''
      Plymouth theme to use.
      Available built-in themes:
      - breeze (default KDE theme)
      - bgrt (shows manufacturer logo)
      - spinner (simple spinner)
      - script (scriptable theme)
      - tribar (three bars)
      - fade-in (fade in animation)
      - glow (glowing logo)
      - solar (solar system)
      - spinfinity (infinity spinner)
    '';

    logo = mkOpt (nullOr path) null ''
      Path to a custom logo to display during boot.
      If null, uses the default NixOS logo or theme's default.
    '';

    silentBoot = mkBoolOpt true ''
      Enable silent boot (hide kernel messages).
      Makes boot look cleaner with just the splash screen.
    '';
  };

  config = mkIf cfg.enable {
    boot.plymouth = {
      enable = true;
      theme = cfg.theme;
      logo = cfg.logo;
    };

    # Silent boot settings
    boot.kernelParams = mkIf cfg.silentBoot [
      "quiet"
      "splash"
      "vt.global_cursor_default=0"
    ];
    boot.consoleLogLevel = mkIf cfg.silentBoot 0;
    boot.initrd.verbose = mkIf cfg.silentBoot false;
  };
}
