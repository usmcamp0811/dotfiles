{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
let cfg = config.campground.services.firefly;
in {
  options.campground.services.firefly = with types; {
    enable = mkBoolOpt false "Enable Firefly III.";
    dataDir = mkOpt str "/var/lib/firefly" "Data directory for Firefly III.";
    APP_URL =
      mkOpt str "https://${cfg.domain}" "Application URL for Firefly III.";
    DB_HOST = mkOpt str "localhost" "Database host for Firefly III.";
    DB_PORT = mkOpt int 5432 "Database port for Firefly III.";
    DB_CONNECTION =
      mkOpt str "pgsql" "Database connection type for Firefly III.";
    APP_ENV = mkOpt str "production" "Application environment for Firefly III.";
    virtualHost =
      mkOpt str "firefly.lan.aicampground.com" "Virtual host for Firefly III.";
    package = mkOpt types.package pkgs.firefly-iii "Package for Firefly III.";
    poolConfig = mkOpt attrs { max_connections = 10; }
      "Pool configuration for Firefly III.";

    role-id =
      mkOpt str config.campground.services.vault-agent.settings.vault.role-id
      "Absolute path to the Vault role-id";
    secret-id =
      mkOpt str config.campground.services.vault-agent.settings.vault.secret-id
      "Absolute path to the Vault secret-id";
    vault-path = mkOpt str "secret/campground/firefly"
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

    services.nginx = {
      enable = true;
      virtualHosts = {
        "${cfg.virtualHost}" = {
          listen = [{
            addr = "0.0.0.0";
            port = 16244;
          }];
        };
      };
    };
    campground.services.postgresql = {
      enable = true;
      authentication = [ "local firefly firefly trust" ];
      databases = [{
        name = "firefly";
        user = "firefly";
      }];
    };
    services.firefly-iii = {
      enable = true;
      user = "firefly";
      group = "firefly";
      dataDir = cfg.dataDir;
      settings = {
        APP_URL = cfg.APP_URL;
        DB_HOST = cfg.DB_HOST;
        DB_PORT = cfg.DB_PORT;
        DB_CONNECTION = cfg.DB_CONNECTION;
        APP_KEY_FILE = "/tmp/detsys-vault/key.file";
        APP_ENV = cfg.APP_ENV;
      };
      virtualHost = cfg.virtualHost;
      package = cfg.package;
      poolConfig = cfg.poolConfig;
    };
    campground.services = {
      vault-agent = {
        services = {
          "firefly-iii-setup" = {
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
                  "key.file" = {
                    text = ''
                      {{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.key }}{{ else }}{{ .Data.data.key }}{{ end }}{{ end }} '';
                    permissions = "0600";
                    change-action = "restart";
                  };
                };
              };
            };
          };
        };
      };
    };
  };
}
