{ pkgs, lib, nixos-hardware, nixosModules, ... }:

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

  boot.initrd.availableKernelModules = [ "thunderbolt" "xhci_hcd" ];

  services.logind.lidSwitch = "ignore";
  campground = {
    # nix = {
    #   package = pkgs.nixVersions.nix_2_18;
    # };
    archetypes = {
      workstation = enabled;
    };
    desktop.qtile = {
      enable = true;
      gdm = true;
    };

    # apps = {
    #   virtmanager = enabled;
    # };

    system = {
      boot = enabled;
      zfs = {
        enable = true;
        hostId = "5ae58e7a";
        keyfile-url = "key-server.lan:1234/zfs-keyfile";
      };
      # manage local passwd in vault
      passwds = enabled;
      # wifi = {
      # # TODO: is there anything I can do to clean this up a little.. seems a little verbose
      #   enable = false;
      #   networks = {
      #     SkyNet = {
      #       ssid = "SkyNet";
      #     };
      #     SkyNet5 = {
      #       ssid = "SkyNet5";
      #     };
      #   };
      # };
      # vpn = {
      #   enable = false;
      #   networks = {
      #     CampNet = {
      #       key = "ata_xps";
      #     };
      #   };
      # };
    };

    hardware.audio = {
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
    postgresql = {
      enable = true;
      databases = [
        { 
          name = "my-test-db"; 
          users = ["root_user"];
        }
      ];
    };
    # jupyter = enabled;
    syncthing = enabled;
    tang = enabled;
    k0sworker = enabled;
    zfs-key-server = {
      enable = true;
      port = 8123;
      tang-servers = [
       "http://webb:1234" 
       "http://daly:1234" 
       "http://ermy:1234" 
      ];
    };
    user-secrets = {
      enable = true;
      users = {
        mcamp =  {
          files = [
            "id_ed25519"
            "passwords"
          ];
        };
      };
    };
    vault-agent = {
      enable = true;
      settings = {
        vault = {
          address = "https://vault.lan.aicampground.com";
          role-id = "/var/lib/vault/mattis/role-id";
          secret-id = "/var/lib/vault/mattis/secret-id";
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

