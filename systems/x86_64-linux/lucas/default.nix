{ pkgs, config, lib, nixos-hardware, nixosModules, ... }:

with lib;
with lib.campground;

let
  newUser = name: {
    isNormalUser = true;
    createHome = true;
    home = "/home/${name}";
    shell = pkgs.zsh;
  };
in {
  imports = [ ./hardware.nix ];
  campground = {
    user = {
      name = "mcamp";
      fullName = "Matt Camp";
      email = "matt@aicampground.com";
      extraGroups = [ "wheel" "docker" ];
      uid = 10000;
    };

    # deploy-user = enabled;
    archetypes = {
      workstation = enabled;
      server = {
        enable = true;
        k8s = true;
        role = "worker";
        hostId = "930864f0";
      };
    };
    # security.acme = enabled;
    suites = {
      public-hosting = {
        enable = true;
        interface = "eno1";
      };
    };
    nfs.client.enable = true;
    tools.attic = enabled;

    hardware = { nvidia = enabled; };

    # security = {
    #   doas = enabled;
    # };
    services = {
      matt-camp-website = enabled;
      attic-watch-store = enabled;
      gitlab-runner = enabled;
      zookeeper = { enable = true; };
      apache-kafka = { enable = true; };
      # netmaker = {
      #   enable = true;
      # };
      # postgresql = {
      #   enable = true;
      #   enableTCPIP = true;
      #   backupEnable = true;
      #   backupLocation = "/persist/postgresqlBackups/";
      #   authentication = ''
      #     local all root trust
      #     local all postgres peer
      #     local netmaker netmaker trust
      #     host  netmaker  netmaker  127.0.0.1/32 trust
      #     host  all  all  0.0.0.0/0  reject
      #     host  all  all  ::0/0  reject
      #   '';
      # };
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
