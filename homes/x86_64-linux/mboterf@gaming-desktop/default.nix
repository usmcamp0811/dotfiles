{ inputs, lib, pkgs, config, osConfig ? { }, format ? "unknown", ... }:
with lib;
with lib.campground;
{

  
  campground = {
    user = {
      enable = true;
      name = config.snowfallorg.user.name;
    };
    desktop = {
      addons = {
        waynergy = enabled;
        rofi = enabled;
        swaynotificationcenter = enabled;
        networkmanagerapplet = enabled;
        #swayidle = enabled;
        swaylock = enabled;
        input-leap = enabled;
        qt = enabled;
        kitty = enabled;
        waybar = {
          enable = true;
          display = "DP-1";
        };
        hyprpaper = {
          enable = true;
          monitors = [
            { name = "DP-1"; wallpaper = "${pkgs.campground.wallpapers}/share/wallpapers/atmosphere.png"; }
            { name = "DP-2"; wallpaper = "${pkgs.campground.wallpapers}/share/wallpapers/atmosphere.png"; }
          ];

          wallpapers = [
            "${pkgs.campground.wallpapers}/share/wallpapers/atmosphere.png"
          ];
        };
        gbar = enabled;
        wofi = enabled;
      };
      wallpapers = enabled;
      # cinnamon = enabled;
     # qtile = {
     #   enable = true;
     #   wallpaper = "atmosphere.png";
     # };
      hyprland = {
        enable = true;
        startup = [
          "${getExe pkgs.networkmanagerapplet}"
          "${getExe pkgs.firefox}"
          "${getExe pkgs.mattermost}"
          "${getExe pkgs._1password-gui} --silent"
        ];
      };
    };

    cli = {
      zsh = enabled;
      bash = enabled;
      env = enabled;
      home-manager = enabled;
      k9s = enabled;
      broot = enabled;
      ranger = enabled;
      spacevim = enabled;
      # neovim = enabled;
    };
    services = {
      # picom = enabled;
    };

    apps = {
      firefox = enabled;
      brave = enabled;
      libreoffice = enabled;
      alacritty = enabled;
      mpv = enabled;
      zoom = enabled;
      #webcord = enabled;
      lutris = enabled;
      minecraft = enabled;
      signal = enabled;
      prismlauncher = enabled;
     # mattermost-desktop = enabled;
     # slack = enabled;
      onepass = enabled;
      logseq = enabled;
      #TODO: Add Qutebrowser
    };
    tools = {
      git = {
        enable = true;
        userEmail = "michaelboterf@gmail.com";
        userName = "Michael Boterf";
      };
      direnv = enabled;
      virtmanager = enabled;
      #julia = enabled;
      #python = enabled;
      vault = {
        enable = true;
        vault-addr = "http://10.2.0.215:8200";
      };
      liquidctl = enabled;
      mangohud = enabled;
      emoji-picker = enabled;
      scientific-fhs = enabled;
      # noisetorch = enabled;
    };
  };

  home.stateVersion = "23.11";
}
