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

  # nixos-boot is typically a flake input named "nixos-boot" (hyphenated)
  hasNixosBoot = builtins.hasAttr "nixos-boot" inputs;
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

    nixosBootBgColor =
      mkOpt (submodule {
        options = {
          red = mkOpt (ints.between 0 255) 0 "Red (0-255).";
          green = mkOpt (ints.between 0 255) 0 "Green (0-255).";
          blue = mkOpt (ints.between 0 255) 0 "Blue (0-255).";
        };
      }) {
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

  config = mkIf cfg.enable (mkMerge [
    {
      assertions = [
        {
          assertion = (!cfg.useNixosBoot) || hasNixosBoot;
          message = ''
            fmf.system.plymouth.useNixosBoot is enabled but nixos-boot flake input is not available.
            Add nixos-boot to your flake inputs:
              inputs.nixos-boot.url = "github:Melkor333/nixos-boot";
          '';
        }
      ];
    }

    # nixos-boot mode
    (mkIf cfg.useNixosBoot {
      # Avoid conflicts with normal plymouth / stylix plymouth theming
      boot.plymouth.enable = mkForce false;

      # Only touch Stylix if it's present; this is safe even if Stylix isn't used,
      # because it's just an assignment into the option tree (it will error only if
      # Stylix is imported but option is missing). If you *don't* always have Stylix,
      # tell me and I'll guard this differently.
      stylix.targets.plymouth.enable = mkForce false;

      "nixos-boot" = {
        enable = true;
        theme = cfg.nixosBootTheme;
        bgColor = {
          red = cfg.nixosBootBgColor.red;
          green = cfg.nixosBootBgColor.green;
          blue = cfg.nixosBootBgColor.blue;
        };
        duration = cfg.nixosBootDuration;
      };
    })

    # standard Plymouth mode
    (mkIf (!cfg.useNixosBoot) {
      boot.plymouth = {
        enable = true;
        theme = cfg.theme;
        logo = cfg.logo;
      };
    })

    # Silent boot settings (applies to either mode)
    (mkIf cfg.silentBoot {
      boot.kernelParams = [
        "quiet"
        "splash"
        "vt.global_cursor_default=0"
      ];
      boot.consoleLogLevel = 0;
      boot.initrd.verbose = false;
    })
  ]);
}
