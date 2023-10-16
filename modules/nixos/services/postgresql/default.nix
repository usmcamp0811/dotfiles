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
    vault-path = mkOpt str "secret/campground/database-users" "The Vault path to the KV containing the KVs that are for each database";
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
    databases = mkOption {
      type = listOf (submodule {
        options = {
          name = mkOption {
            type = str;
            description = "Database name";
          };
          user = mkOption {
            type = str;
            description = "User who should have full access to the database";
          };
        };
      });
      description = "Databases to initialize, along with a privileged user for each.";
    };
    package = mkOpt package pkgs.postgresql_13 "What PostgreSQL to use";
    enableTCPIP = mkBoolOpt false "Enable TCP access";
    authentication = mkOption {
      type = str;
      default = ''
        # Allow only local connections for the root user
        local all root trust 
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
      package = cfg.package;
      enableTCPIP = cfg.enableTCPIP;
      authentication = cfg.authentication;
      ensureDatabases = map (db: db.name) cfg.databases;
      ensureUsers = map (db: {
        name = db.user;
        ensurePermissions = {
          "DATABASE ${db.name}" = "ALL PRIVILEGES";
        };
        ensureClauses = {
          login = true; # or however you wish to set this
        };
      }) cfg.databases;
    };

    systemd.services.set-postgres-passwords = {
      description = "Set PostgreSQL user passwords";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.postgresql}/bin/psql -f /tmp/detsys-vault/set-passwords.sql";
        User = "postgres";
      };
      after = [ "postgresql.service" ];
      wantedBy = [ "multi-user.target" ];
      preStart = "echo 'Preparing to set PostgreSQL passwords'";
    };

    campground.services.vault-agent.services.set-postgres-passwords = {
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
            "set-passwords.sql" = {
              text = builtins.concatStringsSep "\n" (map (db: ''
                {{ with secret "${cfg.vault-path}" }}
                ALTER USER ${db.user} WITH PASSWORD '{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.${db.user}.password }}{{ else }}{{ .Data.data.${db.user}.password }}{{ end }}';
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


