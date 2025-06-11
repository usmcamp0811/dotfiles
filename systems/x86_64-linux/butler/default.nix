{ pkgs
, config
, lib
, inputs
, ...
}:
with lib;
with lib.campground; let
  newUser = name: {
    isNormalUser = true;
    createHome = true;
    home = "/home/${name}";
    shell = pkgs.zsh;
  };
in
{
  imports = [ ./hardware.nix ];

  services.tlp = { enable = mkForce false; };
  programs.adb.enable = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;
  # hardware.nvidia.package = config.boot.kernelPackages.nvidiaPackages.mkDriver {
  #   version = "555.42.02";
  #   sha256_64bit = "sha256-k7cI3ZDlKp4mT46jMkLaIrc2YUx1lh1wj/J4SVSHWyk=";
  #   sha256_aarch64 = "sha256-rtDxQjClJ+gyrCLvdZlT56YyHQ4sbaL+d5tL4L4VfkA=";
  #   openSha256 = "sha256-rtDxQjClJ+gyrCLvdZlT56YyHQ4sbaL+d5tL4L4VfkA=";
  #   settingsSha256 = "sha256-rtDxQjClJ+gyrCLvdZlT56YyHQ4sbaL+d5tL4L4VfkA=";
  #   persistencedSha256 = lib.fakeSha256;
  # };
  campground = {
    user = {
      name = "mcamp";
      fullName = "Matt Camp";
      email = "matt@aicampground.com";
      extraGroups = [ "wheel" "docker" "adbusers" "kvm" ];
      uid = 10000;
    };
    # stig = {
    #   # enable = true;
    #   banner = {
    #     enable = false;
    #     justification = [ "i said so" ];
    #   };
    # };
    desktop.cinnamon = enabled;
    suites = {
      public-hosting = {
        enable = true;
        interface = "enp0s13f0u3";
      };
      # kubernetes = {
      #   enable = true;
      #   role = "worker";
      #   interface = "enp0s13f0u3";
      #   # isLeader = true;
      # };
    };
    apps = { steam = enabled; };

    archetypes = {
      laptop = enabled;
      workstation = enabled;
    };

    nfs.client = { enable = true; };

    hardware = {
      bluetooth = enabled;
      # nvidia-prime = enabled;
    };

    services = {
      k3s = {
        # enable = true;
        serverAddr = "10.8.0.197";
        role = "agent";
      };
      ldap-client = { enable = mkForce false; };
      attic-watch-store = enabled;
      zfs-key-server = {
        enable = true;
        tang-servers = [
          "http://pikvm:1234"
          "http://webb:1234"
          "http://lucas:1234"
          "http://chesty:1234"
        ];
      };
      netbird.client = enabled;
      # wireguard-client = {
      #   enable = true;
      #   port = 1149;
      #   ips = [ "10.100.0.2/32" ];
      #   ip = "10.100.0.2/32";
      #   publicKey = "uMOWdQXLQL7QHstypM/yrSw1kTpMZKysRA/SxSjAZwA=";
      # };
      user-secrets = {
        enable = true;
        users = {
          mcamp = { files = [ "id_ed25519" "passwords" "kubeconfig" ]; };
        };
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
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.05"; # Did you read the comment?
}
