{
  options,
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.desktop.addons.mpvpaper;
in {
  options.fmf.desktop.addons.mpvpaper = {
    enable = mkEnableOption "mpvpaper - video wallpaper using mpv";

    monitors = mkOption {
      description = "Monitors and their video wallpapers";
      type = with types;
        listOf (submodule {
          options = {
            name = mkOption {
              type = str;
              description = "Monitor name (use '*' for all monitors)";
            };
            wallpaper = mkOption {
              type = path;
              description = "Path to video file (MP4, MKV, etc.)";
            };
            mpvOptions = mkOption {
              type = listOf str;
              default = [];
              description = "Additional mpv options";
              example = ["--loop" "--volume=0"];
            };
          };
        });
      default = [];
    };

    defaultMpvOptions = mkOption {
      type = types.listOf types.str;
      default = [
        "--loop-file=inf"
        "--no-audio"
        "--panscan=1.0"
        "--no-osc"
        "--no-osd-bar"
        "--osd-level=0"
        "--no-input-default-bindings"
        "--no-stop-screensaver"
      ];
      description = "Default mpv options applied to all wallpapers";
    };

    layer = mkOption {
      type = types.enum ["background" "bottom" "top" "overlay"];
      default = "background";
      description = "Wayland layer to render on";
    };

    autoStart = mkOption {
      type = types.bool;
      default = true;
      description = "Automatically start mpvpaper on login";
    };
  };

  config = mkIf cfg.enable {
    # Create systemd services for each monitor
    systemd.user.services = mkMerge (map (monitor: let
      serviceName = "mpvpaper-${replaceStrings ["*" " "] ["all" "-"] monitor.name}";
      allOptions = cfg.defaultMpvOptions ++ monitor.mpvOptions;
      optionsStr = concatStringsSep " " allOptions;
    in {
      "${serviceName}" = mkIf cfg.autoStart {
        Unit = {
          Description = "mpvpaper wallpaper for ${monitor.name}";
          PartOf = ["graphical-session.target"];
          After = ["graphical-session.target"];
        };

        Service = {
          Type = "simple";
          ExecStart = "${pkgs.mpvpaper}/bin/mpvpaper ${optionsStr} --layer ${cfg.layer} ${monitor.name} ${monitor.wallpaper}";
          Restart = "on-failure";
          RestartSec = 3;
        };

        Install.WantedBy = ["hyprland-session.target"];
      };
    }) cfg.monitors);

    # Helper script to start mpvpaper manually
    home.packages = [
      pkgs.mpvpaper
      (pkgs.writeShellScriptBin "mpvpaper-start" ''
        if [ $# -lt 2 ]; then
          echo "Usage: mpvpaper-start <monitor> <video-path> [mpv-options...]"
          echo "Example: mpvpaper-start DP-1 ~/videos/wallpaper.mp4 --loop --no-audio"
          echo ""
          echo "Available monitors:"
          ${pkgs.hyprland}/bin/hyprctl monitors | ${pkgs.gnugrep}/bin/grep "Monitor" | ${pkgs.gawk}/bin/awk '{print "  " $2}'
          exit 1
        fi

        MONITOR="$1"
        VIDEO="$2"
        shift 2

        if [ ! -f "$VIDEO" ]; then
          echo "Error: Video file not found: $VIDEO"
          exit 1
        fi

        # Kill existing mpvpaper for this monitor
        ${pkgs.procps}/bin/pkill -f "mpvpaper.*$MONITOR"

        # Start new mpvpaper
        ${pkgs.mpvpaper}/bin/mpvpaper \
          ${concatStringsSep " " cfg.defaultMpvOptions} \
          "$@" \
          --layer ${cfg.layer} \
          "$MONITOR" \
          "$VIDEO" &

        echo "Started mpvpaper on $MONITOR with $VIDEO"
      '')

      (pkgs.writeShellScriptBin "mpvpaper-stop" ''
        if [ $# -eq 0 ]; then
          echo "Stopping all mpvpaper instances..."
          ${pkgs.procps}/bin/pkill mpvpaper
        else
          MONITOR="$1"
          echo "Stopping mpvpaper on $MONITOR..."
          ${pkgs.procps}/bin/pkill -f "mpvpaper.*$MONITOR"
        fi
      '')

      (pkgs.writeShellScriptBin "mpvpaper-restart" ''
        echo "Restarting mpvpaper services..."
        ${concatStringsSep "\n" (map (monitor: let
          serviceName = "mpvpaper-${replaceStrings ["*" " "] ["all" "-"] monitor.name}";
        in ''
          systemctl --user restart ${serviceName}
        '') cfg.monitors)}
      '')
    ];
  };
}
