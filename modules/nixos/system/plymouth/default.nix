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
    enable = mkBoolOpt false ''
      Whether to enable Plymouth boot splash screen.
      When enabled, Plymouth will also theme the LUKS password prompt
      if you have encrypted disks.
    '';

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

    themePackages = mkOpt (listOf package) [] ''
      List of Plymouth theme packages to install.
      Available packages from nixpkgs:
      - pkgs.adi1090x-plymouth-themes (80+ themes collection)
      - pkgs.catppuccin-plymouth (pastel theme)
      - pkgs.plymouth-matrix-theme (Matrix animation)
      - pkgs.plymouth-proxzima-theme (techno animation)
      - pkgs.plymouth-blahaj-theme (IKEA shark)
      - pkgs.nixos-bgrt-plymouth (NixOS spinning logo)
    '';

    logo =
      mkOpt (nullOr path)
      "${pkgs.nixos-icons}/share/icons/hicolor/48x48/apps/nix-snowflake-white.png" ''
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
      theme = mkDefault cfg.theme;
      logo = cfg.logo;
      themePackages = cfg.themePackages;
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
