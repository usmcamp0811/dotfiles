{ lib, ... }:
with lib;
with lib.campground;
# let
#   newUser = name: {
#     isNormalUser = true;
#     createHome = true;
#     home = "/home/${name}";
#     shell = pkgs.zsh;
#   };
# in 
{
  imports = [ ./hardware.nix ];
  campground = {
    nfs.client.enable = true;
    user = {
      name = "mcamp";
      fullName = "Matt Camp";
      email = "matt@aicampground.com";
      extraGroups = [ "wheel" ];
      GroupsIds = {
        users = 10000;
        k8s = 999;
        paperless = 317;
      };
      uid = 10000;
    };

    suites = {
      lan-hosting = {
        enable = true;
        interface = "enp7s0";
      };
      kafka = {
        enable = true;
        interface = "enp7s0";
        zookeeper-id = 1;
        servers = ''
          server.1=127.0.0.1:2888:3888
          server.2=webb:2888:3888
          server.3=daly:2888:3888
          server.4=lucas:2888:3888
        '';
      };
    };
    archetypes = {
      server = {
        enable = true;
        k8s = false;
        role = "worker";
        hostId = "13ec383b";
      };
    };
    hardware = { nvidia = enabled; };
    services = {
      ldap-client = { enable = mkForce false; };
      attic-watch-store = enabled;
      # hydra = enabled;
      jellyfin = enabled;
      searx = {
        enable = true;
        port = 3249;
      };
      zfs-key-server = {
        enable = true;
        port = 8123;
        tang-servers = [
          "http://daly:1234"
          "http://lucas:1234"
          # "http://ermy:1234"
          "http://webb:1234"
          "http://reckless:1234"
        ];
      };
      user-secrets = {
        enable = true;
        users.mcamp = { files = [ "id_ed25519" "passwords" ]; };
      };
      vault-agent = {
        enable = true;
        settings = {
          vault = {
            address = "https://vault.lan.aicampground.com";
            role-id = "/var/lib/vault/chesty/role-id";
            secret-id = "/var/lib/vault/chesty/secret-id";
          };
        };
      };
    };
  };

  system.stateVersion = "23.05";
}
