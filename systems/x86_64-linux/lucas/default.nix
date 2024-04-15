{ lib, ... }:
with lib;
with lib.campground;
{
  imports = [ ./hardware.nix ];

  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
  campground = {
    user = {
      name = "mcamp";
      fullName = "Matt Camp";
      email = "matt@aicampground.com";
      extraGroups = [ "wheel" "docker" ];
      uid = 10000;
    };
    archetypes = {
      workstation = enabled;
      server = {
        enable = true;
        k8s = true;
        role = "worker";
        hostId = "930864f0";
      };
    };
    suites = {
      public-hosting = {
        enable = true;
        interface = "eno1";
      };
      kafka = { 
        enable = true; 
        zookeeper-id = 0;
      };
    };
    nfs.client.enable = true;
    tools.attic = enabled;

    hardware = { nvidia = enabled; };
    services = {
      matt-camp-website = enabled;
      attic-watch-store = enabled;
      gitlab-runner = enabled;
      searx = {
        enable = true;
        port = 3249;
      };
      zfs-key-server = {
        enable = true;
        port = 8123;
        tang-servers = [
          # "http://daly:1234"
          # "http://mattis:1234"
          "http://chesty:1234"
          "http://ermy:1234"
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
            role-id = "/var/lib/vault/lucas/role-id";
            secret-id = "/var/lib/vault/lucas/secret-id";
          };
        };
      };
    };
  };

  system.stateVersion = "23.05";
}
