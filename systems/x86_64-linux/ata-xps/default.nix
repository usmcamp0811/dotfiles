{ pkgs, lib, nixos-hardware, ... }:

with lib;
with lib.internal;
let
  newUser = name: {
    isNormalUser = true;
    createHome = true;
    home = "/home/${name}";
    shell = pkgs.zsh;
    # ... any other common settings ...
  };
in
{
  imports = [ ./hardware.nix ];

  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
  campground = {
    archetypes = {
      workstation = enabled;
    };

    apps = {
      # steam = enabled;
    };

    system = {
      # zfs = enabled;
      boot = enabled;
    };

    hardware.audio = {
    #   alsa-monitor.rules = [
    #     (mkAlsaRename {
    #       name = "alsa_card.usb-Generic_Blue_Microphones_2240BAH095W8-00";
    #       description = "Blue Yeti";
    #     })
    #     (mkAlsaRename {
    #       name = "alsa_output.usb-Generic_Blue_Microphones_2240BAH095W8-00.analog-stereo";
    #       description = "Blue Yeti";
    #     })
    #     (mkAlsaRename {
    #       name = "alsa_input.usb-Generic_Blue_Microphones_2240BAH095W8-00.analog-stereo";
    #       description = "Blue Yeti";
    #     })
    #   ];
    };
  };

  campground.home.extraOptions = {
    # dconf.settings = {
    #   "org/gnome/shell/extensions/just-perfection" = {
    #     panel-size = 60;
    #   };
    # };
  };

  campground.user = {
    name = "mcamp";
    fullName = "Matt Camp";
    email = "matt@aicampground.com";
    initialPassword = "password";
    extraGroups = ["wheel"];
  };
  campground.services.openssh = {
    
  }


  {
    users.users = {
      alice = newUser "alice";
      bob = newUser "bob";
    };
  }
  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.05"; # Did you read the comment?
}
