{ inputs, lib, pkgs, config, osConfig ? { }, format ? "unknown", ... }:
with lib;
with lib.campground; {
  campground = {

    system.xdg = enabled;
    user = {
      name = "mcamp";
      fullName = "Matt Camp";
      email = "matt@aicampground.com";
      uid = 10000;
    };
    archetypes.desktop = {
      enable = true;
      display-name = "HDMI-A-3";
    };
    services.protonmail-bridge = enabled;
    apps.thunderbird = enabled;
    # desktop = {
    #   addons = {
    #     waynergy = enabled;
    #     rofi = enabled;
    #     swaynotificationcenter = enabled;
    #     networkmanagerapplet = enabled;
    #     swayidle = enabled;
    #     swaylock = enabled;
    #     input-leap = enabled;
    #     qt = enabled;
    #     kitty = enabled;
    #     waybar = {
    #       enable = true;
    #       display = "HDMI-A-3";
    #     };
    #     hyprpaper = {
    #       enable = true;
    #       monitors = [
    #         {
    #           name = "HDMI-A-1";
    #           wallpaper =
    #             "${pkgs.campground.wallpapers}/share/wallpapers/pittsburgh-wallpaper.jpeg";
    #         }
    #         {
    #           name = "HDMI-A-2";
    #           wallpaper =
    #             "${pkgs.campground.wallpapers}/share/wallpapers/pittsburgh-wallpaper.jpeg";
    #         }
    #         {
    #           name = "HDMI-A-3";
    #           wallpaper =
    #             "${pkgs.campground.wallpapers}/share/wallpapers/pittsburgh-wallpaper.jpeg";
    #         }
    #       ];
    #
    #       wallpapers = [
    #         "${pkgs.campground.wallpapers}/share/wallpapers/hsv-saturnV.jpg"
    #         "${pkgs.campground.wallpapers}/share/wallpapers/pittsburgh-wallpaper.jpeg"
    #       ];
    #     };
    #     gbar = enabled;
    #     wofi = enabled;
    #   };
    #   wallpapers = enabled;
    #   qtile = {
    #     enable = true;
    #     wallpaper = "hsv-saturnV.jpg";
    #   };
    #   hyprland = {
    #     enable = true;
    #     startup = [ "${getExe pkgs.ckb-next} -b" ];
    #   };
    # };

  };

  home.stateVersion = "23.05";
}
