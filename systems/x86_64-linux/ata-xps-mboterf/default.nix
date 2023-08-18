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
  campground = {
    archetypes = {
      workstation = enabled;
    };

    apps = {
      emacs = {
        enable = true;
        spacemacs = true;
      };
      firefox = {
        enable = false;
        cac = true;
      };
      brave = {
        enable = true;
        cac = true;
      };
    };

    system = {
      boot = enabled;
      wifi = {
      # TODO: is there anything I can do to clean this up a little.. seems a little verbose
        enable = false;
        networks = {
          SkyNet = {
            ssid = "SkyNet";
          };
          SkyNet5 = {
            ssid = "SkyNet5";
          };
        };
      };
      vpn = {
        enable = false;
        networks = {
          CampNet = {
            key = "ata_xps";
          };
        };
      };
    };

    hardware.audio = {
    };

  };

  campground.home.extraOptions = {
  };

  campground.user = {
    name = "mboterf";
    fullName = "Michael Boterf";
    email = "michaelboterf@gmail.com";
    initialPassword = "password";
    extraGroups = ["wheel"];
  };

  campground.services = {
    ldap-client = disabled;
    secret-service = disabled;
    cac = {
      enable = true;
    };
    vault-agent = {
      enable = false;
      settings = {
        vault = {
          address = "https://vault.lan.aicampground.com";
          role-id = "/var/lib/vault/ata-xps/role-id";
          secret-id = "/var/lib/vault/ata-xps/secret-id";
        };
      };
    };
  };


  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.05"; # Did you read the comment?
}
