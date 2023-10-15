{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
{
  options.campground.services.postgresql = with types; {
    enable = mkBoolOpt false "Enable PostgreSQL on a server";
    role-id = mkOpt str config.campground.services.vault-agent.settings.vault.role-id "Absolute path to the Vault role-id";
    secret-id = mkOpt str config.campground.services.vault-agent.settings.vault.secret-id "Absolute path to the Vault secret-id";
    vault-path = mkOpt str "secret/campground/postgresql" "The Vault path to the KV containing the User Secrets.";
    kvVersion = mkOption {
      type = enum ["v1" "v2"];
      default = "v2";
      description = "KV store version";
    };
    vault-address = mkOption {
      type = str;
      default = config.campground.services.vault-agent.settings.vault.address;
      description = "The address of your Vault";
    };
    databases = mkOpt list [] "List of Databases to init from Vault.";

  };

  config = mkIf cfg.enable {
    services.postgresql.initialScript = "/tmp/detsys-vault/psql_init.sql";
    campground.services.vault-agent.services.postgresql = {
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
            "psql_init.sql" = {
              text = builtins.concatStringsSep "\n" (map (dbName: ''
                {{ with secret "${cfg.vault-path}/${dbName}" }}
                CREATE DATABASE ${dbName};
                CREATE USER {{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.username }}{{ else }}{{ .Data.data.username }}{{ end }} WITH PASSWORD '{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.password }}{{ else }}{{ .Data.data.password }}{{ end }}';
                GRANT ALL PRIVILEGES ON DATABASE ${dbName} TO {{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.username }}{{ else }}{{ .Data.data.username }}{{ end }};
                {{ end }}
              '') cfg.databases);
              permissions = "0600";
              change-action = "restart";
            };
          };
        };
      };
    };
  };
}


