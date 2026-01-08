{
  options,
  config,
  lib,
  pkgs,
  inputs ? {},
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.system.plymouth;

  # Check if nixos-boot is available
  hasNixosBoot = inputs ? nixos-boot;
in {
  options.fmf.system.plymouth = with types; {
    enable = mkBoolOpt false "Whether to enable Plymouth boot splash screen.";

    useNixosBoot = mkBoolOpt false ''
      Use the nixos-boot animated themes (load_unload or evil-nixos).
      Requires nixos-boot flake input to be added.
      Note: This increases initrd size by ~50MB.
    '';

    nixosBootTheme = mkOpt str "evil-nixos" ''
      Which nixos-boot theme to use when useNixosBoot is enabled.
      Options:
      - evil-nixos: Spinning NixOS logo with red/communist styling
      - load_unload: Growing and shrinking NixOS logo animation
    '';

    nixosBootBgColor = mkOpt (attrsOf int) {
      red = 0;
      green = 0;
      blue = 0;
    } ''
      Background color for nixos-boot themes (RGB 0-255).
      Default is black (0,0,0).
    '';

    nixosBootDuration = mkOpt float 0.0 ''
      Duration in seconds to display the nixos-boot splash screen.
      0.0 means it stays until boot completes.
    '';

    theme = mkOpt str "breeze" ''
      Plymouth theme to use (only when useNixosBoot is false).
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
      Only applies when useNixosBoot is false.
    '';

    silentBoot = mkBoolOpt true ''
      Enable silent boot (hide kernel messages).
      Makes boot look cleaner with just the splash screen.
    '';
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = !cfg.useNixosBoot || hasNixosBoot;
        message = ''
          fmf.system.plymouth.useNixosBoot is enabled but nixos-boot flake input is not available.
          Add nixos-boot to your flake inputs:
            inputs.nixos-boot.url = "github:Melkor333/nixos-boot";
        '';
      }
    ];

    # Use nixos-boot configuration when enabled
    services.nixos-boot = mkIf cfg.useNixosBoot {
      enable = true;
      theme = cfg.nixosBootTheme;
      bgColor = cfg.nixosBootBgColor;
      duration = cfg.nixosBootDuration;
    };

    # Use standard Plymouth when not using nixos-boot
    boot.plymouth = mkIf (!cfg.useNixosBoot) {
      enable = true;
      theme = cfg.theme;
      logo = cfg.logo;
    };

    # Silent boot configuration (applies to both)
    boot.kernelParams = mkIf cfg.silentBoot [
      "quiet"
      "splash"
      "vt.global_cursor_default=0"
    ];

    boot.consoleLogLevel = mkIf cfg.silentBoot 0;
    boot.initrd.verbose = mkIf cfg.silentBoot false;
  };
}
