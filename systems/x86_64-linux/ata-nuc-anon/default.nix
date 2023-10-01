{ pkgs, lib, ... }:

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
  # boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
  # boot.kernelPackages = pkgs.linuxPackages_latest;
  services.logind.lidSwitch = "ignore";
  campground = {
    archetypes = {
      workstation = enabled;
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
      vscode = enabled;
      virtualbox = enabled;
      virtmanager = enabled;
      libreoffice = enabled;
      barrier = enabled;
    };

    security = {
      keyring = enabled;
    };

    system = {
      # manage local passwd in vault
      # passwds = enabled;
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
      clevis = {
        enable = true;
        keyfile-url = "http://ata-xps:8080/zfs-keyfile";
      };

      time = {
        enable = true;
        TZ = "America/New_York";
      };
      # vpn = {
      #   enable = false;
      #   networks = {
      #     CampNet = {
      #       key = "ata-nuc-anon";
      #     };
      #   };
      # };
    };

    hardware.audio = {
    };
  };

  campground.user = {
    name = "mgarvis";
    fullName = "Matt Camp";
    email = "mgarvis@ata-llc.com";
    extraGroups = ["wheel"];
  };

  campground.services = {
    # ldap-client = enabled;
    # secret-service = enabled;
    cac = enabled;
    user-secrets = {
      enable = false;
      users = {
        mcamp =  {
          files = [
            "id_ed25519"
            "passwords"
            "kubeconfig"
          ];
        };
      };
    };
    vault-agent = {
      enable = false;
      settings = {
        vault = {
          address = "https://vault.lan.aicampground.com";
          role-id = "/var/lib/vault/ata-nuc-anon/role-id";
          secret-id = "/var/lib/vault/ata-nuc-anon/secret-id";
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

