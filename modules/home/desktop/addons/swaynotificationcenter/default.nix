{ options, config, lib, pkgs, ... }:

with lib;
with lib.campground;
let 
  cfg = config.campground.desktop.addons.swaynotificationcenter;
in
{
  options.campground.desktop.addons.swaynotificationcenter = {
    enable = mkEnableOption "Hyprpaper";
  };

  config = mkIf cfg.enable { 

    home.packages = with pkgs; [
      swaynotificationcenter
      libnotify
    ];

    xdg.configFile = {
      "rofi" = {
        source = lib.cleanSourceWith {
          src = lib.cleanSource ./config/.;
        };

        recursive = true;
      };
    };
  };
}

