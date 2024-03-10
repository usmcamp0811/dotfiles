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

  # findEnabledServices = { serviceName }: builtins.filter (name: let
  #   cfg = self.nixosConfigurations.${name}.config.services.${serviceName}.enable;
  #   in cfg) (builtins.attrNames self.nixosConfigurations);
  # searxEnabledSystems = findEnabledServices { serviceName = "searx"; };
  # searxURLs = map (host: {
  #   # You need to obtain the port for each service dynamically if it varies; otherwise, specify it directly if constant
  #   url = "http://${host}:${cfg.port}"; # Replace PORT with the actual port or a method to retrieve it dynamically
  # }) searxEnabledSystems;
in
{
  imports = [ ./hardware.nix ];

  campground = {
    user = {
      name = "mcamp";
      fullName = "Matt Camp";
      email = "matt@aicampground.com";
      extraGroups = ["wheel" "docker"];
      uid = 10000;
    };
    suites = {
      hosting = {
        enable = true;
        interface = "eno1";
        pub-interface = true;
      };
    };

    archetypes = {
      server = {
        enable = true;
        k8s = true;
        role = "worker";
        hostId = "119db424";
      };
    };

    tools = {
      attic = enabled;
    };

    services = {
      ldap-client = {
        enable = mkForce false;
      };
      # keycloak = {
      #   enable = true;
      # };
      attic-watch-store = enabled;
      nixery = enabled;
      docker = enabled;
      minio = enabled;
      mlflow = enabled;
      # airflow = enabled;
      # label-studio = enabled;
      vaultwarden = enabled;
      mattermost = enabled;
      paperless = enabled;
      searx = {
        enable = true;
        port = 3249;
      };

      mysql = {
        backupEnable = true;
        backupLocation = "/persist/mysqlBackups/";
      };

      photoprism = {
        enable = true;
        originalsPath = "/webb/media/photos";
      };

      borgbackup = {
        enable = true;
        jobs = {
          "campground" = {
            paths = [ 
              "/persist" 
              "/webb/media/photos"
              "/webb/kubernetes"
              "/webb/backups/openwrt-backups"
              "/var/lib/paperless"
              "/var/lib/minio"
              "/var/lib/label-studio"
              "/var/lib/mattermost/files"
            ];
            repo = "mcamp@reckless:/mnt/backups/webb";
            startAt = "daily";
          };
          "webb_rsync" = {
            paths = [ 
              "/persist" 
              "/webb/media/photos"
              "/webb/kubernetes"
              "/webb/backups/openwrt-backups"
              "/var/lib/paperless"
              "/var/lib/minio"
              "/var/lib/label-studio"
              "/var/lib/mattermost/files"
            ];
            repo = "de3288@de3288.rsync.net:/data2/home/de3288/backups/webb";
            startAt = "daily";
          };
        };
      };
      postgresql = {
        enable = true;
        enableTCPIP = true;
        backupEnable = true;
        backupLocation = "/persist/postgresqlBackups/";
        authentication = ''
          local all root trust
          local all postgres peer
          local vaultwarden vaultwarden trust
          local mattermost mattermost trust
          local mlflow mlflow trust
          local labelstudio labelstudio trust
          local paperless paperless trust
          local netmaker netmaker trust
          local postgres netmaker trust
          host  paperless paperless 127.0.0.1/32 trust
          host  netmaker  netmaker  127.0.0.1/32 trust
          host  keycloak  keycloak  127.0.0.1/32 trust
          host  all  all  0.0.0.0/0  reject
          host  all  all  ::0/0  reject
        '';
      };
      # wireguard = {
      #   enable = true;
      #   port = 1149;
      #   ips = [ "10.100.0.1/24" ];
      #   peers = [
      #     { # butler
      #       publicKey = "Thdtm9iUmcZFgFMiJUm0T0EaBe/gvfmcBHrSi5Gvfm8=";
      #       presharedKeyFile = "/var/lib/wireguard/wg0-preshared-key";
      #       allowedIPs = [ "10.100.0.2/32" ];
      #     }
      #     { # phone
      #       publicKey = "cq5+lO9tjEom1pUuXtb9rfAfSN6DZxDZkKWdVQ6Cokw=";
      #       presharedKeyFile = "/var/lib/wireguard/wg0-preshared-key";
      #       allowedIPs = [ "10.100.0.3/32" ];
      #     }
      #   ];
      # };
      zfs-key-server = {
        enable = true;
        port = 8123;
        tang-servers = [ 
          "http://daly:1234" 
          "http://lucas:1234" 
          "http://reckless:1234"
          "http://chesty:1234"
          "http://ermy:1234" 
        ];
      };
      user-secrets = {
        enable = true;
        users.mcamp = { 
          files = [ 
            "id_ed25519" 
            "passwords" 
          ]; 
        };
      };

      vault-agent = {
        enable = true;
        settings = { 
          vault = { 
            address = "http://vault.lan";
            role-id = "/var/lib/vault/webb/role-id"; 
            secret-id = "/var/lib/vault/webb/secret-id"; 
          }; 
        };
      };
    };
    nfs.client = enabled;
  };

  system.stateVersion = "23.05";
}
