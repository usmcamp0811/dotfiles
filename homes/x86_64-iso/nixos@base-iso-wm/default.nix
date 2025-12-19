{
  lib,
  pkgs,
  config,
  osConfig ? {},
  format ? "unknown",
  ...
}:
with lib;
with lib.fmf; {
  fmf = {
    user = {
      enable = true;
      name = config.snowfallorg.user.name;
    };

    cli = {
      zsh = enabled;
      home-manager = enabled;
      env = enabled;
    };
    desktop = {
      addons = {
        waynergy = enabled;
        rofi = enabled;
        swaynotificationcenter = enabled;
        networkmanagerapplet = enabled;
        swayidle = enabled;
        swaylock = enabled;
        kitty = enabled;
        waybar = {
          enable = true;
          display = "HDMI-A-3";
        };
        hyprpaper = {
          enable = true;
          monitors = [
            {
              name = "HDMI-A-3";
              wallpaper = "${pkgs.fmf.wallpapers}/share/wallpapers/hsv-saturnV.jpg";
            }
            {
              name = "HDMI-A-2";
              wallpaper = "${pkgs.fmf.wallpapers}/share/wallpapers/hsv-saturnV.jpg";
            }
            {
              name = "eDP-1";
              wallpaper = "${pkgs.fmf.wallpapers}/share/wallpapers/hsv-saturnV.jpg";
            }
          ];

          wallpapers = [
            "${pkgs.fmf.wallpapers}/share/wallpapers/hsv-saturnV.jpg"
          ];
        };
        wofi = enabled;
      };
      wallpapers = enabled;
      hyprland = {
        enable = true;
        startup = ["${getExe pkgs.networkmanagerapplet}"];
      };
    };
  };
  home.stateVersion = "23.05";
}
