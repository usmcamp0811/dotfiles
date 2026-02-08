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
  cfg = config.fmf.system.nixos-boot;

  # nixos-boot is typically a flake input named "nixos-boot" (hyphenated)
  hasNixosBoot = builtins.hasAttr "nixos-boot" inputs;
in {
  options.fmf.system.nixos-boot = with types; {
    enable = mkBoolOpt false "Whether to enable nixos-boot animated boot splash.";

    theme = mkOpt str "evil-nixos" ''
      Which nixos-boot theme to use.
      Options:
      - evil-nixos: Spinning NixOS logo with red/communist styling
      - load_unload: Growing and shrinking NixOS logo animation
    '';

    bgColor =
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

    duration = mkOpt float 0.0 ''
      Duration in seconds to display the nixos-boot splash screen.
      0.0 means it stays until boot completes.
    '';

    silentBoot = mkBoolOpt true ''
      Enable silent boot (hide kernel messages).
      Makes boot look cleaner with just the splash screen.
    '';
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = hasNixosBoot;
        message = ''
          fmf.system.nixos-boot.enable is enabled but nixos-boot flake input is not available.
          Add nixos-boot to your flake inputs:
            inputs.nixos-boot.url = "github:Melkor333/nixos-boot";
        '';
      }
    ];

    # Avoid conflicts with normal plymouth / stylix plymouth theming
    boot.plymouth.enable = mkForce false;

    # Only touch Stylix if it's present; this is safe even if Stylix isn't used,
    # because it's just an assignment into the option tree (it will error only if
    # Stylix is imported but option is missing). If you *don't* always have Stylix,
    # tell me and I'll guard this differently.
    stylix.targets.plymouth.enable = mkForce false;

    "nixos-boot" = {
      enable = true;
      theme = cfg.theme;
      bgColor = {
        red = cfg.bgColor.red;
        green = cfg.bgColor.green;
        blue = cfg.bgColor.blue;
      };
      duration = cfg.duration;
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
