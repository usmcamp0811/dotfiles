{ pkgs, lib, nixos-hardware, nixosModules, ... }:

with lib;
with lib.campground;
{
  campground = {
    apps = {
    };

    system = {
      time = {
        enable = true;
        TZ = "America/Chicago";
      };
    };

    tools = {
      git = enabled;
    };

  };

  campground.home.extraOptions = {
    home.shellAliases = {
      la = "lsd -lah";
    };
  };

  campground.user = {
    name = "vault";
    fullName = "Matt";
    email = "mcamp@ata-llc.com";
    extraGroups = ["wheel"];
  };

  campground.services = {
  };


  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.05"; # Did you read the comment?
}

