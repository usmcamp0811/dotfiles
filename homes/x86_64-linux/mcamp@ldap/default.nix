{ inputs, lib, pkgs, config, osConfig ? { }, format ? "unknown", ... }:
with lib;
with lib.campground; {
  campground = {
    user = {
      enable = true;
      name = "mcamp";
      fullName = "Matt Camp";
      email = "matt@aicampground.com";
    };
    desktop = {
      addons = {
        waynergy = enabled;
        rofi = enabled;
        swaynotificationcenter = enabled;
        networkmanagerapplet = enabled;
        swayidle = enabled;
        swaylock = enabled;
        input-leap = enabled;
        qt = enabled;
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
              wallpaper =
                "${pkgs.campground.wallpapers}/share/wallpapers/hsv-saturnV.jpg";
            }
            {
              name = "HDMI-A-2";
              wallpaper =
                "${pkgs.campground.wallpapers}/share/wallpapers/hsv-saturnV.jpg";
            }
            {
              name = "eDP-1";
              wallpaper =
                "${pkgs.campground.wallpapers}/share/wallpapers/hsv-saturnV.jpg";
            }
          ];

          wallpapers = [
            "${pkgs.campground.wallpapers}/share/wallpapers/hsv-saturnV.jpg"
          ];
        };
        gbar = enabled;
        wofi = enabled;
      };
      wallpapers = enabled;
      qtile = {
        enable = true;
        wallpaper = "hsv-saturnV.jpg";
      };
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
      neovim = enabled;
      misc = enabled;
    };
    services = {
      openssh = {
        enable = true;
        extraConfigs = ''
          Host github.com-usmcamp0811
            HostName github.com
            User git
            IdentityFile ~/.ssh/id_ed25519
            IdentitiesOnly yes

          Host github.com-mcamp-ata
            HostName github.com
            User git
            IdentityFile ~/.ssh/id_rsa.ata
            IdentitiesOnly yes
        '';
      };
      syncthing = enabled;
    };

    apps = {
      barrier = enabled;
      firefox = enabled;
      brave = enabled;
      libreoffice = enabled;
      alacritty = enabled;
      mpv = enabled;
      zoom = enabled;
      qutebrowser = enabled;
      ckb-next = enabled;
      mattermost-desktop = enabled;
      slack = enabled;
    };
    tools = {
      git = enabled;
      vault = enabled;
      direnv = enabled;
      virtmanager = enabled; # don't forget to add to libvirtd group
      julia = enabled;
      # jupyter = enabled;
      # python = enabled;
      emoji-picker = enabled;
      # dvc = enabled;
    };
  };

  home.stateVersion = "23.05";
}
