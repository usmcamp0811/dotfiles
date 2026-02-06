{
  options,
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.desktop.addons.swww;
in {
  options.fmf.desktop.addons.swww = {
    enable = mkEnableOption "swww - animated wallpaper daemon";

    monitors = mkOption {
      description = "Monitors and their wallpapers";
      type = with types;
        listOf (submodule {
          options = {
            name = mkOption {
              type = str;
              description = "Monitor name";
            };
            wallpaper = mkOption {
              type = path;
              description = "Path to wallpaper (supports images, GIFs, and videos)";
            };
          };
        });
      default = [];
    };

    transition = {
      type = mkOption {
        type = types.str;
        default = "wipe";
        description = "Transition type (simple, fade, wipe, grow, outer, random, etc.)";
      };

      duration = mkOption {
        type = types.int;
        default = 2;
        description = "Transition duration in seconds";
      };

      fps = mkOption {
        type = types.int;
        default = 60;
        description = "Frame rate for animations";
      };

      angle = mkOption {
        type = types.int;
        default = 45;
        description = "Angle for wipe transitions (0-360)";
      };
    };

    fillColor = mkOption {
      type = types.str;
      default = "000000";
      description = "Background fill color (hex without #)";
    };
  };

  config = mkIf cfg.enable {
    # Systemd service for swww daemon
    systemd.user.services.swww-daemon = {
      Unit = {
        Description = "swww animated wallpaper daemon";
        PartOf = ["graphical-session.target"];
        After = ["graphical-session.target"];
      };

      Service = {
        ExecStart = "${pkgs.swww}/bin/swww-daemon";
        Restart = "on-failure";
        RestartSec = 3;
      };

      Install.WantedBy = ["hyprland-session.target"];
    };

    # Script to set wallpapers after daemon starts
    systemd.user.services.swww-init = mkIf (cfg.monitors != []) {
      Unit = {
        Description = "Initialize swww wallpapers";
        After = ["swww-daemon.service"];
        Requires = ["swww-daemon.service"];
        PartOf = ["graphical-session.target"];
      };

      Service = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStartPre = "${pkgs.coreutils}/bin/sleep 1";
        ExecStart = let
          wallpaperScript = pkgs.writeShellScript "swww-set-wallpapers" ''
            ${concatStringsSep "\n" (map (monitor: ''
              ${pkgs.swww}/bin/swww img \
                --outputs ${monitor.name} \
                --transition-type ${cfg.transition.type} \
                --transition-duration ${toString cfg.transition.duration} \
                --transition-fps ${toString cfg.transition.fps} \
                --transition-angle ${toString cfg.transition.angle} \
                ${monitor.wallpaper}
            '') cfg.monitors)}
          '';
        in "${wallpaperScript}";
      };

      Install.WantedBy = ["hyprland-session.target"];
    };

    # Helper script for manual wallpaper changes
    home.packages = [
      pkgs.swww
      (pkgs.writeShellScriptBin "swww-set" ''
        if [ $# -eq 0 ]; then
          echo "Usage: swww-set <wallpaper-path> [monitor]"
          echo "Example: swww-set ~/wallpapers/video.mp4 DP-1"
          exit 1
        fi

        WALLPAPER="$1"
        MONITOR="''${2:-}"

        if [ ! -f "$WALLPAPER" ]; then
          echo "Error: File not found: $WALLPAPER"
          exit 1
        fi

        MONITOR_FLAG=""
        if [ -n "$MONITOR" ]; then
          MONITOR_FLAG="--outputs $MONITOR"
        fi

        ${pkgs.swww}/bin/swww img \
          $MONITOR_FLAG \
          --transition-type ${cfg.transition.type} \
          --transition-duration ${toString cfg.transition.duration} \
          --transition-fps ${toString cfg.transition.fps} \
          --transition-angle ${toString cfg.transition.angle} \
          "$WALLPAPER"
      '')
    ];
  };
}
