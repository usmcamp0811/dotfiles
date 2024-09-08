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
              name = "HDMI-A-1";
              wallpaper =
                "${pkgs.campground.wallpapers}/share/wallpapers/hsv-saturnV.jpg";
            }
            {
              name = "HDMI-A-2";
              wallpaper =
                "${pkgs.campground.wallpapers}/share/wallpapers/hsv-saturnV.jpg";
            }
            {
              name = "HDMI-A-3";
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
        startup = [ "${getExe pkgs.ckb-next} -b" ];
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
    };
    services = {
      openssh = enabled;
      syncthing = {
        enable = true;

        settings = {
          gui = {
            user = "mcamp";
            password = "password";
            address = "0.0.0.0:8384";
          };
          devices = {
            "webb" = {
              id =
                "CDYQGNY-J456EPJ-FRWJ4RS-CLETCLG-7L6QC4K-KP3HO7L-IY62FMD-ZTJFKQT";
            };
            "pixel" = {
              id =
                "AQYP35O-7TCNUMN-HM2KOQF-U4RSGNM-C7SNIEM-TGES2ZC-XRJXO2H-7FOWWAB";
            };
          };
          folders = {
            #   "Documents" = {
            #     # Name of folder in Syncthing, also the folder ID
            #     path = "/home/myusername/Documents"; # Which folder to add to Syncthing
            #     devices = [
            #       "device1"
            #       "device2"
            #     ]; # Which devices to share the folder with
            #   };
            #   "Example" = {
            #     path = "/home/myusername/Example";
            #     devices = [ "device1" ];
            #     ignorePerms = false; # By default, Syncthing doesn't sync file permissions. This line enables it for this folder.
            #   };
          };
        };
      };
      protonmail-bridge = enabled;
    };

    apps = {
      thunderbird = enabled;
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
      compose2nix = enabled;
      freetube = enabled;
    };
    tools = {
      git = enabled;
      vault = enabled;
      direnv = enabled;
      virtmanager = enabled; # don't forget to add to libvirtd group
      emoji-picker = enabled;
      julia = enabled;
      jupyter = enabled;
      python = enabled;
      node = enabled;
    };
  };

  home.stateVersion = "23.05";
}
