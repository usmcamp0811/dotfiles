{ pkgs, lib, inputs,... }:

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

  # services.xserver.videoDrivers = [ "nouveau" ];
  # boot.blacklistedKernelModules = [ "nvidia" "nvidia_drm" "nvidia_modeset" "nvidia_uvm" ];
  # boot.kernelPackages = pkgs.linuxPackages_zen;


  campground = {
    system.boot = enabled;
    # archetypes = {
    #   workstation = enabled;
    # };
    #
    # desktop.qtile = {
    #   enable = true;
    #   gdm = true;
    # };

    # apps = {
    #   k9s = enabled; 
    #   virtmanager = enabled;
    # };

    # security = {
    #   keyring = enabled;
    # };

    # nfs = {
    #   campfs = enabled;
    # };

    system = {
      # manage local passwd in vault
      zfs = {
        enable = true;
        hostId = "9151fb2a";
        keyfile-url = "http://10.8.0.1:1234/zfs-keyfile";
      };
      # passwds = enabled;
      # wifi = {
      # # TODO: is there anything I can do to clean this up a little.. seems a little verbose
      #   enable = true;
      #   networks = {
      #     SkyNet = {
      #       ssid = "SkyNet";
      #     };
      #     SkyNet5 = {
      #       ssid = "SkyNet5";
      #     };
      #   };
      # };
      # vpn = enabled;
    };

    hardware.audio = {
    };

    # hardware.nvidia = enabled;
    # hardware.intel = enabled;

  };

  campground.user = {
    name = "abe";
    fullName = "Matt Camp";
    email = "matt@aicampground.com";
    extraGroups = ["wheel"];
  };

  campground.services = {
    # docker = enabled;
    # # jupyter = enabled;
    # zfs-key-server = {
    #   enable = false;
    #   tang-servers = [
    #    "http://webb:1234" 
    #    "http://lucas:1234" 
    #    "http://ermy:1234" 
    #   ];
    # };
    # ldap-client = enabled;
    # secret-service = enabled;
    # cac = {
    #   enable = false;
    # };
    # user-secrets = {
    #   enable = true;
    #   users = {
    #     mcamp =  {
    #       files = [
    #         "id_ed25519"
    #         "passwords"
    #         "kubeconfig"
    #       ];
    #     };
    #   };
    # };
    # vault-agent = {
    #   enable = true;
    #   settings = {
    #     vault = {
    #       address = "https://vault.lan.aicampground.com";
    #       role-id = "/var/lib/vault/ata-nuc/role-id";
    #       secret-id = "/var/lib/vault/ata-nuc/secret-id";
    #     };
    #   };
    # };
  };

#  users.users.mcamp = {
#    isNormalUser = true;
#    home = "/home/mcamp";
#    group = "ldap_user";
#    shell = pkgs.zsh;
#
#    # Arbitrary user ID to use for the user. Since I only
#    # have a single user on my machines this won't ever collide.
#    # However, if you add multiple users you'll need to change this
#    # so each user has their own unique uid (or leave it out for the
#    # system to select).
#    uid = 10000;
#  }; 

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

