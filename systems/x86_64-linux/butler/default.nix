{ pkgs, lib, nixos-hardware, nixosModules, agenix, ... }:

with lib;
with lib.internal;
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

    apps = {
      firefox = {
        enable = false;
        cac = false;
      };
      brave = {
        enable = true;
        cac = false;
      };
    };

    system = {
      boot = enabled;
      # manage local passwd in vault
      passwds = enabled;
      wifi = {
      # TODO: is there anything I can do to clean this up a little.. seems a little verbose
        enable = true;
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
        enable = true;
        networks = {
          CampNet = {
            key = "butler";
          };
        };
      };
    };

    hardware.audio = {
    };

    hardware.nvidia = enabled;

  };

  campground.home.extraOptions = {
    home.shellAliases = {
      la = "lsd -lah";
      update = "sudo nixos-rebuild switch";
    };
  };

  campground.user = {
    name = "abe";
    fullName = "Matt Camp";
    email = "matt@aicampground.com";
    extraGroups = ["wheel"];
  };

  campground.services = {
    ldap-client = enabled;
    secret-service = enabled;
    cac = {
      enable = false;
    };
    vault-agent = {
      enable = true;
      settings = {
        vault = {
          address = "https://vault.lan.aicampground.com";
          role-id = "/var/lib/vault/butler/role-id";
          secret-id = "/var/lib/vault/butler/secret-id";
        };
      };
    };
  };
  # TODO: Move this somewhere more good and try to automate for when not connected to a monitor
  environment.variables = {
    GDK_SCALE = "1.6";
    GDK_DPI_SCALE = "1.6";
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.05"; # Did you read the comment?
}

