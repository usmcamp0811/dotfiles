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
in
{
  imports = [ ./hardware.nix ];

  campground = {
    archetypes.workstation = enabled;
    tools.icehouse = enabled;
    nfs.campfs = enabled;
    # nfs.chestyfs = enabled;

    system = {
      boot = enabled;
      zfs = {
        enable = true;
        hostId = "119db424";
        keyfile-url = "http://10.8.0.1:1234/zfs-keyfile";
      };
      passwds = enabled;
    };

    user = {
      name = "abe";
      fullName = "Matt Camp";
      email = "matt@aicampground.com";
      extraGroups = ["wheel"];
    };

    services = {
      # TODO: configure searx
      # searx = {
      #   enable = true;
      # };
      minio = {
        enable = true;
      };
      mlflow = {
        enable = true;
        # port = 5000;
      };
      mattermost = enabled;
      mysql = {
        backupEnable = true;
        backupLocation = "/persist/mysqlBackups/";
      };
      photoprism = {
        enable = true;
        originalsPath = "/webb/media/photos";
      };
      paperless = {
        enable = true;
      };

      borgbackup = {
        enable = true;
        jobs = {
          "campground-backups" = {
            paths = [ 
              "/persist" 
              "/webb/media/photos"
              "/var/lib/paperless"
              "/var/lib/minio"
            ];
            repo = "mcamp@chesty:/mnt/backups/";
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
          host  paperless paperless 127.0.0.1/32 trust
          host  all  all  0.0.0.0/0  reject
          host  all  all  ::0/0  reject
        '';
      };

      vaultwarden = { 
        enable = true; 
      };
      openssh = { 
        authorizedKeys = [ 
          "ecdsa-sha2-nistp521 AAAAE2VjZHNhLXNoYTItbmlzdHA1MjEAAAAIbmlzdHA1MjEAAACFBAGs9njLHA3yyrX6BTf5Z3Xj8jzOh9zVYfJoeai6WhmBtjr34KV0F79YKafvJPS4gasOTFpnKXObvBo0jG3/AIN+dwBohHtFtXSYBgZecFg847XoeN+7cIveqgI2Q1Jn2sFoUTzGiwKxqLRM7ZuTtRJGfoizOxlYHdyovus67jfDxewP5A== mcamp@Butler"
        ];
      };
      ldap-client = enabled;
      tang = enabled;
      k0sworker = enabled;
      ntp = enabled;
      label-studio = enabled;
      wireguard = {
        enable = true;
        port = 1149;
        ips = [ "10.100.0.1/24" ];
        peers = [
          { # butler
            publicKey = "Thdtm9iUmcZFgFMiJUm0T0EaBe/gvfmcBHrSi5Gvfm8=";
            presharedKeyFile = "/var/lib/wireguard/wg0-preshared-key";
            allowedIPs = [ "10.100.0.2/32" ];
          }
          { # phone
            publicKey = "cq5+lO9tjEom1pUuXtb9rfAfSN6DZxDZkKWdVQ6Cokw=";
            presharedKeyFile = "/var/lib/wireguard/wg0-preshared-key";
            allowedIPs = [ "10.100.0.3/32" ];
          }
        ];
      };

      zfs-key-server = {
        enable = true;
        port = 8123;
        tang-servers = [ 
          "http://daly:1234" 
          # "http://mattis:1234" 
          "http://lucas:1234" 
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
            address = "https://vault.lan.aicampground.com"; 
            role-id = "/var/lib/vault/webb/role-id"; 
            secret-id = "/var/lib/vault/webb/secret-id"; 
          }; 
        };
      };
    };
  };

  system.stateVersion = "23.05";
}
