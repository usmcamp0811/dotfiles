{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
let
  cfg = config.campground.services.postgresql;

in
{
  options.campground.services.postgresql = with types; {
    enable = mkBoolOpt false "Enable PostgreSQL on a server";
    role-id = mkOpt str config.campground.services.vault-agent.settings.vault.role-id "Absolute path to the Vault role-id";
    secret-id = mkOpt str config.campground.services.vault-agent.settings.vault.secret-id "Absolute path to the Vault secret-id";
    vault-path = mkOpt str "secret/campground/postgresql" "The Vault path to the KV containing the KVs that are for each database";
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
    databases = mkOpt (listOf str) [] "List of Databases to init from Vault.";
    package = mkOpt package pkgs.postgresql_13 "What PostgreSQL to use";
    enableTCPIP = mkBoolOpt false "Enable TCP access";
    authentication = mkOption {
      type = str;
      default = ''
        # Allow only local connections for the root user
        local all postgres peer
        # Require password for Vault-generated users over the network
        host  all  all  10.8.0.1/24  md5  
        # Deny other remote connections
        host  all  all  0.0.0.0/0  reject
        host  all  all  ::0/0  reject
      '';
      description = "Authentication settings for PostgreSQL";
    };
    extraInit = mkOpt str "" "Extra stuff to put into the Init script";

  };

  config = mkIf cfg.enable {
    services.postgresql = {
      enable = true;
      initialScript = "/tmp/detsys-vault/psql_init.sql";
      package = cfg.package;
      enableTCPIP = cfg.enableTCPIP;
      authentication = cfg.authentication;
      ensureDatabases = cfg.databases;
    };
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
                ${cfg.extraInit}
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


