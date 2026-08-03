{ options
, config
, lib
, pkgs
, ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.desktop.addons.swaylock;
  
  videoLockScript = pkgs.writeShellScriptBin "video-lock" ''
    set -euo pipefail
    
    VIDEO_DIR="${cfg.videoDirectory}"
    
    # Find a random video from the directory
    if [ -d "$VIDEO_DIR" ] && [ "$(ls -A "$VIDEO_DIR"/*.{mp4,mkv,webm} 2>/dev/null)" ]; then
      VIDEO=$(find "$VIDEO_DIR" -type f \( -name "*.mp4" -o -name "*.mkv" -o -name "*.webm" \) | shuf -n 1)
    else
      # Fallback to a static lock if no videos found
      exec ${pkgs.swaylock-effects}/bin/swaylock
      exit 0
    fi
    
    exec ${pkgs.swaylock-plugin}/bin/swaylock-plugin \
      --command "${pkgs.mpvpaper}/bin/mpvpaper -o \"no-audio --loop-file=inf --panscan=1.0\" ALL \"$VIDEO\""
  '';
in
{
  options.fmf.desktop.addons.swaylock = with types; {
    enable =
      mkBoolOpt false "Whether to enable swaylock in the desktop environment.";
    
    useVideoBackground = mkBoolOpt false "Whether to use video backgrounds for the lock screen";
    
    videoDirectory = mkOption {
      type = str;
      default = "${config.home.homeDirectory}/Videos";
      description = "Directory containing lock screen videos";
    };
  };
  config = mkIf cfg.enable {
    programs.swaylock = {
      enable = true;
      package = pkgs.swaylock-effects;
      settings = mkDefault {
        ignore-empty-password = true;
        disable-caps-lock-text = true;
        font = "MonaspiceAr Nerd Font";
        grace = 300;

        clock = true;
        timestr = "%R";
        datestr = "%a, %e of %B";

        image = "${pkgs.fmf.wallpapers}/share/wallpapers/atmosphere.png";

        fade-in = "0.2";

        effect-blur = "10x2";
        effect-scale = "0.1";

        indicator = true;
        indicator-radius = 240;
        indicator-thickness = 20;
        indicator-caps-lock = true;

        key-hl-color = "#8aadf4";
        bs-hl-color = "#ed8796";
        caps-lock-key-hl-color = "#f5a97f";
        caps-lock-bs-hl-color = "#ed8796";

        separator-color = "#181926";

        inside-color = "#24273a";
        inside-clear-color = "#24273a";
        inside-caps-lock-color = "#24273a";
        inside-ver-color = "#24273a";
        inside-wrong-color = "#24273a";

        ring-color = "#1e2030";
        ring-clear-color = "#8aadf4";
        ring-caps-lock-color = "231f20D9";
        ring-ver-color = "#1e2030";
        ring-wrong-color = "#ed8796";

        line-color = "#8aadf4";
        line-clear-color = "#8aadf4";
        line-caps-lock-color = "#f5a97f";
        line-ver-color = "#181926";
        line-wrong-color = "#ed8796";

        text-color = "#8aadf4";
        text-clear-color = "#24273a";
        text-caps-lock-color = "#f5a97f";
        text-ver-color = "#24273a";
        text-wrong-color = "#24273a";

        debug = true;
      };
    };
    
    # Add video-lock script to PATH when video backgrounds are enabled
    home.packages = mkIf cfg.useVideoBackground [ videoLockScript ];
  };
}
