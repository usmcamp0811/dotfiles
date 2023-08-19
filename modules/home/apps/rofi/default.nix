{ options, config, lib, pkgs, ... }:

with lib;
with lib.campground;
let 
  cfg = config.campground.desktop.addons.rofi;
  rofiConfig = ''
    /** Configured For Applets **/

    configuration {
      show-icons:         true;
      icon-theme:         "Papirus";
      location: 0;
      yoffset: -50;
      xoffset: -20;
    }
    @import "/usr/share/rofi/themes/DarkBlue.rasi"
    @theme "/usr/share/rofi/themes/arthur.rasi"
  '';
in
{
  options.campground.desktop.addons.rofi = with types; {
    enable =
      mkBoolOpt false "Whether to enable Rofi in the desktop environment.";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [ rofi ];

    {
      programs.rofi = {
        enable = true;
        theme = rofiConfig;
      };

      home.packages = with pkgs; [
        rofi
      ];
    # campground.home.configFile."rofi/config.rasi".source = ./config.rasi;
  };
}

