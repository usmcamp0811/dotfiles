{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
let cfg = config.campground.services.mealie;
in {
  options.campground.services.mealie = {
    enable = mkEnableOption "Attic";

    package =
      mkOpt types.package pkgs.mealie "The mealie-server package to use.";

    dbname = mkOpt types.str "mealie" "The db name";

    user = mkOpt types.str "mealie" "The user under which mealie runs.";
    group = mkOpt types.str "mealie" "The group under which mealie runs.";

    # additional_settings =
    #   mkOpt attr { } "Settings for the mealied config file.";
    #
    port = mkOpt types.int 49452 "Port to use";
    listenAddress = mkOpt types.str "0.0.0.0" "Listen Address";
    base-url = mkOpt types.str "https://mealie.lan.aicampground.com" "base url";

    role-id = mkOpt types.str
      config.campground.services.vault-agent.settings.vault.role-id
      "Absolute path to the Vault role-id";
    secret-id = mkOpt types.str
      config.campground.services.vault-agent.settings.vault.secret-id
      "Absolute path to the Vault secret-id";
    vault-path = mkOpt types.str "secret/campground/mealie"
      "The Vault path to the KV containing the KVs that are for each database";
    kvVersion = mkOption {
      type = types.enum [ "v1" "v2" ];
      default = "v2";
      description = "KV store version";
    };
    vault-address = mkOption {
      type = types.str;
      default = config.campground.services.vault-agent.settings.vault.address;
      description = "The address of your Vault";
    };
  };

  config = mkIf cfg.enable {
    users = {
      users = {
        "${cfg.user}" = {
          group = "${cfg.group}";
          isSystemUser = true;
        };
      };
      groups = { "${cfg.group}" = { }; };
    };

    campground.services.postgresql = {
      enable = true;
      databases = [{
        name = "mealie";
        user = "${cfg.user}";
      }];
      authentication = [
        "local   mealie    mealie   trust" # Allow trusted local connections for firefly user to firefly DB
        # "host    mealie    mealie   127.0.0.1/32 trust" # Allow trusted connections from localhost (IPv4) for firefly user to firefly DB
        # "host    mealie    mealie   ::1/128 trust" # Allow trusted connections from localhost (IPv6) for firefly user to firefly DB
        # "host    mealie    mealie   0.0.0.0/0 md5"
      ];
    };
    systemd.services.mealie.serviceConfig.User = cfg.user;
    systemd.services.mealie.serviceConfig.Group = cfg.user;
    services.mealie = {
      port = cfg.port;
      settings = {
        DB_ENGINE = "postgres";
        DB_SERVER =
          "/var/run/postgresql"; # Path to the PostgreSQL socket directory
        DB_PORT = ""; # Leave empty to use the socket
        DB_NAME = cfg.dbname;
        DB_USER = cfg.user;
        DB_PASS = "";
        ALLOW_SIGNUP = "true";
        BASE_URL = cfg.base-url;
        MEDIA_DIR = "/var/lib/mealie/media";
        BACKUP_DIR = "/var/lib/mealie/backup";
        POSTGRES_URL_OVERRIDE =
          "postgresql://${cfg.user}:@/mealie?host=/run/postgresql";
      };
      enable = true;
      credentialsFile = "/var/lib/mealie/creds";
      listenAddress = cfg.listenAddress;
    };

    systemd.services.mealieSecrets = {
      description = "Get mealie Secrets";
      serviceConfig = {
        Type = "oneshot";
        User = "root";
      };
      script = ''
        mkdir -p /var/lib/mealie
        ${pkgs.coreutils}/bin/cp /tmp/detsys-vault/mealie-creds /var/lib/mealie/creds
        chown ${cfg.user}:${cfg.group} /var/lib/mealie/
        chown ${cfg.user}:${cfg.group} /var/lib/mealie/creds
      '';
      wantedBy = [ "multi-user.target" ];
      before = [ "mealie.service" ];

    };
    campground.services.vault-agent.services.mealieSecrets = {
      settings = {
        # replace with the address of your vault
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
            "mealie-creds" = {
              text = ''
                ALLOW_SIGNUP=true
                MAX_WORKERS=1
                WEB_CONCURRENCY=1
                OIDC_AUTH_ENABLED=true
                OIDC_SIGNUP_ENABLED=true
                OPENAI_BASE_URL=http://reckless:11434/v1
                OPENAI_API_KEY=mysecretkey
                OIDC_CONFIGURATION_URL={{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.OIDC_CONFIGURATION_URL }}{{ else }}{{ .Data.data.OIDC_CONFIGURATION_URL }}{{ end }}{{ end }}
                OIDC_CLIENT_ID={{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.OIDC_CLIENT_ID }}{{ else }}{{ .Data.data.OIDC_CLIENT_ID }}{{ end }}{{ end }}
                OIDC_CLIENT_SECRET={{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.OIDC_CLIENT_SECRET }}{{ else }}{{ .Data.data.OIDC_CLIENT_SECRET }}{{ end }}{{ end }}
                OIDC_AUTO_REDIRECT=true
                OIDC_REMEMBER_ME=true
                OIDC_ADMIN_GROUP=mealie-admins
                OIDC_USER_GROUP=mealie-users
                SMTP_HOST={{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.SMTP_HOST }}{{ else }}{{ .Data.data.SMTP_HOST }}{{ end }}{{ end }}
                SMTP_PORT={{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.SMTP_PORT }}{{ else }}{{ .Data.data.SMTP_PORT }}{{ end }}{{ end }}
                SMTP_FROM_NAME={{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.SMTP_FROM_NAME }}{{ else }}{{ .Data.data.SMTP_FROM_NAME }}{{ end }}{{ end }}
                SMTP_AUTH_STRATEGY={{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.SMTP_AUTH_STRATEGY }}{{ else }}{{ .Data.data.SMTP_AUTH_STRATEGY }}{{ end }}{{ end }}
                SMTP_FROM_EMAIL={{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.SMTP_FROM_EMAIL }}{{ else }}{{ .Data.data.SMTP_FROM_EMAIL }}{{ end }}{{ end }}
                SMTP_USER={{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.SMTP_USER }}{{ else }}{{ .Data.data.SMTP_USER }}{{ end }}{{ end }}
                SMTP_PASSWORD={{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.SMTP_PASSWORD }}{{ else }}{{ .Data.data.SMTP_PASSWORD }}{{ end }}{{ end }}
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
