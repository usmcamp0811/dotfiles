{ pkgs, lib, nixos-hardware, nixosModules, agenix, ... }:

with lib;
with lib.campground;
let
  newUser = name: {
    isNormalUser = true;
    createHome = true;
    home = "/home/${name}";
    shell = pkgs.zsh;
  };

in
{
  imports = [ 
    ./hardware.nix
  ];
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
  services.logind.lidSwitch = "ignore";
  campground = {
    archetypes = {
      workstation = enabled;
    };
    desktop.gnome = {
      enable = true;
      gdm = true;
      wallpaper = {
        light = pkgs.campground.wallpapers.nord-rainbow-light-nix-ultrawide;
        dark = pkgs.campground.wallpapers.nord-rainbow-dark-nix-ultrawide;
      };
    };

    desktop.qtile = {
      enable = true;
      gdm = true;
    };

    desktop.cinnamon = {
      enable = true;
      gdm = true;
    };

    apps = {

      emacs = {
        enable = true;
        spacemacs = true;
      };
      firefox = {
        enable = true;
      };
      brave = {
        enable = true;
      };
      vscode = enabled;
      virtualbox = enabled;
      virtmanager = enabled;
      libreoffice = enabled;
    };

    system = {
      boot = enabled;
      time = {
        enable = true;
        TZ = "America/New_York";
      };
    };

    hardware.audio = {
    };

    # hardware.bluetooth = enabled;
  };

  campground.home.extraOptions = {
    home.shellAliases = {
      la = "lsd -lah";
      update = "sudo nixos-rebuild switch";
    };
  };

  campground.user = {
    name = "ajames";
    fullName = "Alex James";
    email = "ajames@ata-llc.com";
    extraGroups = ["wheel"];
  };

  campground.services = {
    cac = enabled;
  };


  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.05"; # Did you read the comment?
}

