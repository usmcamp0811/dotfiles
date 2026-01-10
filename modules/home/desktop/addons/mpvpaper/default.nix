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
              type = nullOr path;
              default = null;
              description = "Path to single video file (MP4, MKV, etc.)";
            };
            playlist = mkOption {
              type = listOf path;
              default = [];
              description = "List of video files to play as a playlist";
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
        "loop-file=inf"
        "loop-playlist=inf"
        "keep-open=always"
        "pause=no"
        "no-audio"
        "no-osc"
        "osd-level=0"
        "no-input-default-bindings"
        "no-stop-screensaver"
      ];
      description = "Default mpv options applied to all wallpapers (without -- prefix, will be passed as -o option=value)";
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
      # Filter out empty options and format with -o prefix
      mpvOptionsStr = concatStringsSep " " (map (opt: "-o ${opt}") (filter (opt: opt != "") allOptions));

      # Determine video source
      videoSource =
        if monitor.wallpaper != null then monitor.wallpaper
        else if monitor.playlist != [] then builtins.head monitor.playlist
        else throw "Either wallpaper or playlist must be specified for monitor ${monitor.name}";

      # Wrapper script to detect resolution and start mpvpaper
      startScript = pkgs.writeShellScript "mpvpaper-start-${monitor.name}" ''
        # Get monitor resolution from hyprctl
        RESOLUTION=$(${pkgs.hyprland}/bin/hyprctl monitors -j | \
          ${pkgs.jq}/bin/jq -r '.[] | select(.name=="${monitor.name}") | "\(.width):\(.height)"')

        if [ -z "$RESOLUTION" ]; then
          echo "Error: Could not detect resolution for monitor ${monitor.name}"
          exit 1
        fi

        WIDTH=$(echo $RESOLUTION | cut -d: -f1)
        HEIGHT=$(echo $RESOLUTION | cut -d: -f2)

        # Build scale filter to fill screen completely
        VF_FILTER="vf=scale=$WIDTH:$HEIGHT:force_original_aspect_ratio=increase,crop=$WIDTH:$HEIGHT"

        # Start mpvpaper with detected resolution
        exec ${pkgs.mpvpaper}/bin/mpvpaper \
          --layer ${cfg.layer} \
          ${mpvOptionsStr} \
          -o "$VF_FILTER" \
          ${monitor.name} \
          ${videoSource}
      '';
    in {
      "${serviceName}" = mkIf cfg.autoStart {
        Unit = {
          Description = "mpvpaper wallpaper for ${monitor.name}";
          PartOf = ["graphical-session.target"];
          After = ["graphical-session.target"];
        };

        Service = {
          Type = "simple";
          ExecStart = "${startScript}";
          Restart = "always";
          RestartSec = 1;
        };

        Install.WantedBy = ["hyprland-session.target"];
      };
    }) cfg.monitors);

    # Helper script to start mpvpaper manually
    home.packages = [
      pkgs.mpvpaper
      (pkgs.writeShellScriptBin "mpvpaper-start" ''
        if [ $# -lt 2 ]; then
          echo "Usage: mpvpaper-start <monitor> <video-path>"
          echo "Example: mpvpaper-start eDP-1 ~/videos/wallpaper.mp4"
          echo ""
          echo "Available monitors:"
          ${pkgs.hyprland}/bin/hyprctl monitors | ${pkgs.gnugrep}/bin/grep "Monitor" | ${pkgs.gawk}/bin/awk '{print "  " $2}'
          exit 1
        fi

        MONITOR="$1"
        VIDEO="$2"

        if [ ! -f "$VIDEO" ]; then
          echo "Error: Video file not found: $VIDEO"
          exit 1
        fi

        # Get monitor resolution from hyprctl
        RESOLUTION=$(${pkgs.hyprland}/bin/hyprctl monitors -j | \
          ${pkgs.jq}/bin/jq -r '.[] | select(.name=="'$MONITOR'") | "\(.width):\(.height)"')

        if [ -z "$RESOLUTION" ]; then
          echo "Error: Could not detect resolution for monitor $MONITOR"
          exit 1
        fi

        WIDTH=$(echo $RESOLUTION | cut -d: -f1)
        HEIGHT=$(echo $RESOLUTION | cut -d: -f2)

        echo "Detected resolution: $WIDTH x $HEIGHT"

        # Build scale filter to fill screen completely
        VF_FILTER="vf=scale=$WIDTH:$HEIGHT:force_original_aspect_ratio=increase,crop=$WIDTH:$HEIGHT"

        # Kill existing mpvpaper for this monitor
        ${pkgs.procps}/bin/pkill -f "mpvpaper.*$MONITOR"

        # Start new mpvpaper with proper looping options and dynamic scaling
        ${pkgs.mpvpaper}/bin/mpvpaper \
          --layer ${cfg.layer} \
          ${concatStringsSep " " (map (opt: "-o ${opt}") cfg.defaultMpvOptions)} \
          -o "$VF_FILTER" \
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
