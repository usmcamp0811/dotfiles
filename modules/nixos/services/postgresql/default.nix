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
          users = mkOption {
            type = listOf str;
            description = "Users who should have full access to the database";
          };
        };
      });
      description = "Databases to initialize, along with privileged users for each.";
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
      initialScript = "/tmp/detsys-vault/psql_init.sql";
      package = cfg.package;
      enableTCPIP = cfg.enableTCPIP;
      authentication = cfg.authentication;
      ensureDatabases = map (db: db.name) cfg.databases;
      ensureUsers = let
        userMap = builtins.foldl' (acc: db: acc // { "${db.name}" = db.users; }) {} cfg.databases;
      in lib.attrsets.mapAttrsToList (dbName: users: {
        name = dbName;
        ensurePermissions = "ALL PRIVILEGES ON DATABASE ${dbName}";
        ensureClauses = {
          login = true; # or however you wish to set this
        };
      }) userMap;

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
            "set-passwords.sql" = {
              text = builtins.concatStringsSep "\n" (map (user: ''
                {{ with secret "${cfg.vault-path}/${user}" }}
                ALTER USER ${user} WITH PASSWORD '{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.password }}{{ else }}{{ .Data.data.password }}{{ end }}';
                {{ end }}
              '') config.services.postgresql.ensureUsers);
              permissions = "0600";
              change-action = "restart";
            };
          };
        };
      };
    };
  };
}


