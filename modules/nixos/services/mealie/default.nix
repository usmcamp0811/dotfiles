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

    additional_settings =
      mkOpt toml-format.type { } "Settings for the mealied config file.";

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
        user = cfg.user;
      }];
    };
    systemd.services.mealie.serviceConfig.User = cfg.user;
    systemd.services.mealie.serviceConfig.Group = cfg.user;
    services.mealie = {
      port = cfg.port;
      settings = {
        DB_ENGINE = "postgres";
        DB_HOST =
          "/var/run/postgresql"; # Path to the PostgreSQL socket directory
        DB_PORT = ""; # Leave empty to use the socket
        DB_NAME = cfg.dbname;
        DB_USER = cfg.user;
        DB_PASS = "";
        MEDIA_DIR = "/var/lib/mealie/media";
        BACKUP_DIR = "/var/lib/mealie/backup";
      } // cfg.additional_settings;
      enable = true;
      credentialsFile = "/tmp/detsys-vault/mealie-creds";
      listenAddress = cfg.listenAddress;
    };

    campground.services.vault-agent.services.mealie = {
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
                OIDC_AUTH_ENABLED=True
                OIDC_CONFIGURATION_URL={{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.OIDC_CONFIGURATION_URL }}{{ else }}{{ .Data.data.OIDC_CONFIGURATION_URL }}{{ end }}{{ end }}
                OIDC_CLIENT_ID={{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.OIDC_CLIENT_ID }}{{ else }}{{ .Data.data.OIDC_CLIENT_ID }}{{ end }}{{ end }}
                OIDC_CLIENT_SECRET={{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.OIDC_CLIENT_SECRET }}{{ else }}{{ .Data.data.OIDC_CLIENT_SECRET }}{{ end }}{{ end }}
                OIDC_AUTO_REDIRECT=True
                OIDC_PROVIDER_NAME=Campground
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
