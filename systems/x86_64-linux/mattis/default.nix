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
  imports = [ ./hardware.nix ];

  boot.initrd.availableKernelModules = [ "thunderbolt" "xhci_hcd" ];

  services.logind.lidSwitch = "ignore";
  campground = {
    user = {
      name = "mcamp";
      fullName = "Matt Camp";
      email = "matt@aicampground.com";
      extraGroups = [ "wheel" "docker" ];
      uid = 10000;
    };

    suites = {
      lan-hosting = {
        enable = true;
        interface = "enp0s20f0u1";
      };
    };

    archetypes = {
      laptop = enabled;
      server = {
        enable = true;
        k8s = false;
        role = "worker";
        hostId = "5ae58e7a";
      };
    };

    nfs.client = {
      campfs = enabled;
      webb = enabled;
      chestyfs = enabled;
    };

    services = {
      # ldap-client = enabled;
      label-studio = enabled;
      postgresql = {
        enable = true;
        enableTCPIP = true;
        backupEnable = true;
        backupLocation = "/persist/postgresqlBackups/";
        authentication = [
          "local all root trust"
          "local all postgres peer"
          "local vaultwarden vaultwarden trust"
          "host  all  all  0.0.0.0/0  reject"
          "host  all  all  ::0/0  reject"
        ];
        databases = [{
          name = "vaultwarden";
          user = "vaultwarden";
        }];
      };
      syncthing = enabled;
      tang = enabled;
      zfs-key-server = {
        enable = true;
        port = 8123;
        interface = "enp0s20f0u1";
        tang-servers = [
          "http://webb:1234"
          "http://daly:1234"
          "http://ermy:1234"
          "http://reckless:1234"
          "http://lucas:1234"
        ];
      };
      user-secrets = {
        enable = true;
        users = { mcamp = { files = [ "id_ed25519" "passwords" ]; }; };
      };
      vault-agent = {
        enable = true;
        settings = {
          vault = {
            address = "http://vault.lan.aicampground.com";
            role-id = "/var/lib/vault/mattis/role-id";
            secret-id = "/var/lib/vault/mattis/secret-id";
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
