{ lib, config, ... }:
with lib;
with lib.campground;
let cfg = config.campground.services.nextcloud;
in {
  options.campground.services.nextcloud = with types; {
    enable = mkBoolOpt false "Enable an Grafana;";
    port = mkOpt int 7443 "Port to Host the nextcloud server on.";

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
      hostName = "${cfg.name}.${this.hostName}";
      home = cfg.dataDir;
      package = pkgs.nextcloud26;
      autoUpdateApps.enable = true;
      caching.apcu = true;
      https = true;
      config = {
        adminuser = builtins.head this.admins;
        adminpassFile = secrets.password.path;
        dbtype = "pgsql";
        dbname = "nextcloud";
        dbhost = "/run/postgresql";
        defaultPhoneRegion = "CA";
        trustedProxies = [
          "127.0.0.1/32" # local host
          "192.168.0.0/16" # local network
          "10.0.0.0/8" # local network
          "172.16.0.0/12" # docker network
          "100.64.0.0/10" # vpn network
        ];
      };
    };

    # Postgres database configuration
    services.postgresql = {
      ensureUsers = [{
        name = "nextcloud";
        ensureDBOwnership = true;
      }];
      ensureDatabases = [ "nextcloud" ];
    };

    # Extend systemd service
    systemd.services.nextcloud-setup = {

      # Secret environment variables (SMTP credentials)
      serviceConfig.EnvironmentFile = secrets.smtp-env.path;

      # Database should be running before this service starts
      after = [ "postgresql.service" ];

      # If the db goes down, take down this service too
      requires = [ "postgresql.service" ];

    };

    # traefik proxy serving nginx proxy
    services.traefik.dynamicConfigOptions.http = {
      routers.nextcloud = {
        rule = "Host(`${cfg.name}.${this.hostName}`)";
        tls.certresolver = "resolver-dns";
        middlewares = [ "local@file" "nextcloud@file" ];
        service = "nextcloud";
      };
      middlewares.nextcloud = {
        headers.customRequestHeaders.Host = "${cfg.name}.${this.hostName}";
      };
      services.nextcloud.loadBalancer.servers = [{
        url = "http://127.0.0.1:${
            toString config.services.nginx.defaultHTTPListenPort
          }";
      }];
    };

    # Allow nextcloud user to read password file
    users.users.nextcloud.extraGroups = [ "secrets" ];

    # Enable database and reverse proxy
    modules.postgresql.enable = true;
    modules.traefik.enable = true;
    modules.nginx.enable = true;

    services.nextcloud = {
      caching.apcu = true;
      caching.redis = true;
      configureRedis = true;

      phpOptions."opcache.interned_strings_buffer" = "64";
      # opcache.memory_consumption=256
      # opcache.interned_strings_buffer=64
      # opcache.max_accelerated_files=100000

      settings = {
        maintenance_window_start = "4";

        trusted_proxies = [ "192.168.7.1" "94.16.108.229" ];

        trusted_domains = [ "birne.wireguard" ];
        default_phone_region = "DE";

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

      enable = true;
      # Pin Nextcloud major version.
      # Refer to upstream docs for updating major versions

      # Workaround for nextcloud bug.
      # TODO remove when https://github.com/nextcloud/server/pull/43794 hits
      # the release
      package = pkgs.nextcloud-patched;

      # Use HTTPS for links
      https = true;
      # overwriteProtocol = "https";
      hostName = "files.pablo.tools";

      # Auto-update Nextcloud Apps
      autoUpdateApps.enable = true;
      autoUpdateApps.startAt = "05:00:00";

      # phpExtraExtensions = [];
      home = "/var/lib/nextcloud";

      poolSettings = {
        pm = "dynamic";
        "pm.max_children" = "160";
        "pm.max_requests" = "700";
        "pm.max_spare_servers" = "120";
        "pm.min_spare_servers" = "40";
        "pm.start_servers" = "40";
      };

      config = {

        # Database
        dbtype = "pgsql";
        dbuser = "nextcloud";
        dbhost = "/run/postgresql";
        dbname = "nextcloud";

        # Admin user
        adminuser = "pinpox";
        adminpassFile =
          "${config.lollypops.secrets.files."nextcloud/admin-pass".path}";
      };

      nginx.recommendedHttpHeaders = true;
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
      secrets.environment.templates = {
        nextcloud = {
          text = ''
            {{ with secret "${cfg.vault-path}" }}
            ADMIN_USER='{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.ADMIN_USER }}{{ else }}{{ .Data.data.ADMIN_USER }}{{ end }}'
            ADMIN_PASSWORD='{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.ADMIN_PASSWORD }}{{ else }}{{ .Data.data.ADMIN_PASSWORD }}{{ end }}'

            {{ end }}
          '';
        };
      };
    };
  };
}
