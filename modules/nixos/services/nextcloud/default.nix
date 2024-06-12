{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
let cfg = config.campground.services.nextcloud;
in {
  options.campground.services.nextcloud = with types; {
    enable = mkBoolOpt false "Enable Nextcloud";
    port = mkOpt int 7443 "Port to host the Nextcloud server on";
    adminuser = mkOpt str "mcmap" "Absolute path to the Vault role-id";
    dataDir = mkOpt str "/var/lib/nextcloud" "Storage path of nextcloud.";

    role-id =
      mkOpt str config.campground.services.vault-agent.settings.vault.role-id
      "Absolute path to the Vault role-id";
    secret-id =
      mkOpt str config.campground.services.vault-agent.settings.vault.secret-id
      "Absolute path to the Vault secret-id";
    vault-path = mkOpt str "secret/campground/nextcloud"
      "The Vault path to the KV containing the KVs that are for each database";
    kvVersion = mkOption {
      type = enum [ "v1" "v2" ];
      default = "v2";
      description = "KV store version";
    };
    vault-address = mkOption {
      type = str;
      default = config.campground.services.vault-agent.settings.vault.address;
      description = "The address of your Vault";
    };
  };

  config = mkIf cfg.enable {

    services.nextcloud = {
      enable = true;
      hostName = "${cfg.name}.${config.networking.domain}";
      home = cfg.dataDir;
      package = pkgs.nextcloud-patched; # Use the patched version
      autoUpdateApps.enable = true;
      autoUpdateApps.startAt = "03:00:00";
      caching.apcu = true;
      caching.redis = true;
      configureRedis = true;
      https = true;
      phpOptions = { "opcache.interned_strings_buffer" = "64"; };
      poolSettings = {
        pm = "dynamic";
        "pm.max_children" = "160";
        "pm.max_requests" = "700";
        "pm.max_spare_servers" = "120";
        "pm.min_spare_servers" = "40";
        "pm.start_servers" = "40";
      };
      config = {
        adminuser = cfg.adminuser;
        adminpassFile = "/tmp/detsys-vault/nextcloud-adminpassFile";
        dbtype = "pgsql";
        dbuser = "nextcloud";
        dbname = "nextcloud";
        dbhost = "/run/postgresql";
        defaultPhoneRegion = "US";
        trustedProxies = [
          "127.0.0.1/32" # local host
          "192.168.0.0/16" # local network
          "10.8.0.0/8" # local network
          "172.16.0.0/12" # docker network
          "100.64.0.0/10" # vpn network
        ];
        trusted_domains = [ "birne.wireguard" ];
        enabledPreviewProviders = [
          "OC\\Preview\\BMP"
          "OC\\Preview\\GIF"
          "OC\\Preview\\JPEG"
          "OC\\Preview\\Krita"
          "OC\\Preview\\MarkDown"
          "OC\\Preview\\MP3"
          "OC\\Preview\\OpenDocument"
          "OC\\Preview\\PNG"
          "OC\\Preview\\TXT"
          "OC\\Preview\\XBitmap"
          "OC\\Preview\\HEIC"
          "OC\\Preview\\Movie"
        ];
      };
    };

    campground.services.postgresql = {
      enable = true;
      authentication = [ "local mlflow mlflow trust" ];
      databases = [{
        name = "nextcloud";
        user = "nextcloud";
      }];
    };

    services.redis = {
      enable = true;
      package = pkgs.redis;
    };

    environment.systemPackages = with pkgs; [ exiftool ffmpeg ];

    campground.services.vault-agent.services.nextcloud = {
      settings = {
        vault.address = cfg.vault-address;
        auto_auth = {
          method = [{
            type = "approle";
            config = {
              role_id_file_path = cfg.role-id;
              secret_id_file_path = cfg.secret-id;
              remove_secret_id_file_after_reading = false;
            };
          }];
        };
      };
      secrets = {
        file = {
          files = {
            "nextcloud-adminpassFile" = {
              text = ''
                {{ with secret "${cfg.vault-path}" }}
                ADMIN_USER='{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.ADMIN_USER }}{{ else }}{{ .Data.data.ADMIN_USER }}{{ end }}'
                ADMIN_PASSWORD='{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.ADMIN_PASSWORD }}{{ else }}{{ .Data.data.ADMIN_PASSWORD }}{{ end }}'
                {{ end }}
              '';
              permissions = "0600";
              change-action = "restart";
            };
          };
        };
      };
    };
  };
}
