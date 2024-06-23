{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
let cfg = config.campground.services.nextcloud;
in {
  options.campground.services.nextcloud = with types; {
    enable = mkBoolOpt false "Enable Nextcloud";
    port = mkOpt int 7443 "Port to host the Nextcloud server on";
    adminuser = mkOpt str "mcamp" "Absolute path to the Vault role-id";
    home = mkOpt str "/var/lib/nextcloud" "App Storage path of nextcloud.";
    dataDir = mkOpt str "/var/lib/nextcloud" "Data Storage path of nextcloud.";
    domain =
      mkOpt str "cloud.aicampground.com" "Trusted Domain to serve Nextcloud On";
    # OnlyOffice configuration
    onlyoffice = mkBoolOpt true "Enable OnlyOffice integration";
    role-id =
      mkOpt str config.campground.services.vault-agent.settings.vault.role-id
      "Absolute path to the Vault role-id";
    secret-id =
      mkOpt str config.campground.services.vault-agent.settings.vault.secret-id
      "Absolute path to the Vault secret-id";
    onlyoffice-vault-path = mkOpt str "secret/campground/onlyoffice"
      "The Vault path to the KV containing the OnlyOffice JWT Token";
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
      hostName = cfg.domain;
      home = cfg.home;
      datadir = cfg.dataDir; # Path for user data
      #TODO: Refactor this so we can keep versions of this inline easier
      package = pkgs.nextcloud29; # Use the patched version
      enableImagemagick = true;
      autoUpdateApps.enable = true;
      autoUpdateApps.startAt = "03:00:00";
      caching.apcu = true;
      caching.redis = true;
      configureRedis = true;
      # https = true;
      phpOptions = { "opcache.interned_strings_buffer" = "64"; };
      poolSettings = {
        pm = "dynamic";
        "pm.max_children" = "160";
        "pm.max_requests" = "700";
        "pm.max_spare_servers" = "120";
        "pm.min_spare_servers" = "40";
        "pm.start_servers" = "40";
      };
      extraApps = {
        # spreed = pkgs.fetchNextcloudApp {
        #   url =
        #     "https://github.com/nextcloud/spreed/archive/refs/tags/v19.0.2.tar.gz";
        #   sha256 = "sha256-KZyVOTnfUR5j2b3Jtl/CBzNBEjwsxsd94C5t9Cz+1Qo=";
        #   license = pkgs.lib.licenses.mit.shortName;
        # };
        cookbook = pkgs.fetchNextcloudApp {
          url =
            "https://github.com/nextcloud/cookbook/releases/download/v0.10.2/Cookbook-0.10.2.tar.gz";
          sha256 = "sha256-XgBwUr26qW6wvqhrnhhhhcN4wkI+eXDHnNSm1HDbP6M=";
          license = pkgs.lib.licenses.mit.shortName;
        };
        # mattermost = pkgs.fetchNextcloudApp {
        #   url =
        #     "https://github.com/nextcloud/integration_mattermost/archive/refs/tags/v1.0.7.tar.gz";
        #   sha256 = "sha256-GhXhoWClI0ER8mXBehsZL/m22382fptlSLSisasGeTA=";
        #   license = pkgs.lib.licenses.mit.shortName;
        # };
        # calendar = pkgs.fetchNextcloudApp {
        #   url =
        #     "https://github.com/nextcloud/calendar/archive/refs/tags/v4.7.6.tar.gz";
        #   license = pkgs.lib.licenses.mit.shortName;
        #   sha256 = "sha256-YO+j4FGri+8rQfvRreUIr4Q57bP8bQzYE6T98W/sQlA=";
        # };
        # mindmap = pkgs.fetchNextcloudApp {
        #   url = "https://github.com/ACTom/files_mindmap/releases/download/v0.0.30/files_mindmap-0.0.30.tar.gz";
        #   sha256 = "sha256-4rAgjDxEH7lXVEoXXKwQRnTi+be0cwl/Uxn2ZRCN6do=";
        #   license = pkgs.lib.licenses.mit.shortName;
        # };
        cospend = pkgs.fetchNextcloudApp {
          url =
            "https://github.com/julien-nc/cospend-nc/releases/download/v1.6.1/cospend-1.6.1.tar.gz";
          sha256 = "sha256-QHIxS5uubutiD9Abm/Bzv1RWG7TgL/tvixVdNEzTlxE=";
          license = pkgs.lib.licenses.mit.shortName;
        };
        forms = pkgs.fetchNextcloudApp {
          url =
            "https://github.com/nextcloud/forms/archive/refs/tags/v4.2.4.tar.gz";
          sha256 = "sha256-dmKpV4f6t6hNZfdxDJRm/Ch6MvftSZTMhHdatBJD0aI=";
          license = pkgs.lib.licenses.mit.shortName;
        };
      };
      config = {
        adminuser = cfg.adminuser;
        # NOTE: Having issues with Nextcloud getting this file or something so I have to manually reset the password
        # export OC_PASS=new_password_here
        # /nix/store/45488dk2sh0v31shz999v0p0i5d21zh9-nextcloud-occ/bin/nextcloud-occ user:resetpassword --password-from-env mcamp
        adminpassFile = "/tmp/detsys-vault/nextcloud-adminpassFile";
        dbtype = "pgsql";
        dbuser = "nextcloud";
        dbname = "nextcloud";
        dbhost = "/run/postgresql";
      };
      settings = {
        defaultPhoneRegion = "US";
        trustedProxies = [
          "127.0.0.1/32" # local host
          "192.168.0.0/16" # local network
          "10.8.0.0/8" # local network
          "172.16.0.0/12" # docker network
          "100.64.0.0/10" # vpn network
        ];
      };
    };

    campground.services.postgresql = {
      enable = true;
      authentication = [ "local nextcloud nextcloud trust" ];
      databases = [{
        name = "nextcloud";
        user = "nextcloud";
      }];
    };

    services.nginx = {
      enable = true;
      commonHttpConfig = ''
        types {
          application/javascript mjs;
        }
      '';
      virtualHosts = {
        "${cfg.domain}" = {
          listen = [{
            addr = "0.0.0.0";
            port = 13244;
          }];
        };
      };
    };

    services.redis.servers = {
      enable = true;
    };

    # OnlyOffice service configuration

    environment.systemPackages = with pkgs; [ exiftool ffmpeg ];

    campground.services.vault-agent.services.nextcloud-setup = {
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
              text = ''{{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.ADMIN_PASSWORD }}{{ else }}{{ .Data.data.ADMIN_PASSWORD }}{{ end }}{{ end }}'';
              permissions = "0600";
              change-action = "restart";
            };
          };
        };
      };
    };
  };
}
