{
  lib,
  pkgs,
  config,
  osConfig ? {},
  format ? "unknown",
  ...
}:
with lib.campground; {
  campground = {
    user = {
      enable = true;
      name = config.snowfallorg.user.name;
    };
    desktop = {
      wallpapers = enabled;
      qtile = {
        enable = true;
        wallpaper = "hsv-saturnV.png";
      };
    };

    cli = {
      zsh = enabled;
      bash = enabled;
      env = enabled;
      home-manager = enabled;
      ranger = enabled;
    };
    services = {
      # picom = enabled;
    };

    apps = {
      firefox = enabled;
      brave = enabled;
      libreoffice = enabled;
      kitty = enabled;
      rofi = enabled;
      mpv = enabled;
    };
    tools = {
      # git = enabled;
      direnv = enabled;
      virtmanager = enabled; # don't forget to add to libvirtd group
      julia = enabled;
      python = enabled;
    };
  };

  home.stateVersion = "23.05";
}
