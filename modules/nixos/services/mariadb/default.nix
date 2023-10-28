{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
let
  cfg = config.campground.services.mysql;

in
{
  options.campground.services.mysql = with types; {
    enable = mkBoolOpt false "Enable MySQL on a server";

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

    package = mkOpt package pkgs.mysql "What MySQL to use";
    # enableTCPIP = mkBoolOpt false "Enable TCP access";
    extraInit = mkOpt str "" "Extra stuff to put into the Init script";
    backupEnable = mkBoolOpt false "Enable backups";
    backupLocation = mkOpt str "/persist/db-backups/" "Place to store backups";
    backupStartAt = mkOpt str "*-*-* 01:15:00" "Time to start backups";
  };

  config = mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = [ 3306 ];  # Open MySQL port
    services.mysql = {
      enable = true;
      package = cfg.package;
      # enableTCPIP = cfg.enableTCPIP;
      ensureDatabases = map (db: db.name) cfg.databases;
      ensureUsers = map (db: {
        name = db.user;
        ensurePermissions = {
          "DATABASE ${db.name}" = "ALL PRIVILEGES";
        };
      }) cfg.databases;
    };

    services.mysqlBackup = {
      enable = cfg.backupEnable;
      location = cfg.backupLocation;
      # startAt = cfg.backupStartAt;
      databases = map (db: db.name) cfg.databases; 
    };

    # systemd.services.set-mysql-passwords = {
    #   description = "Set MySQL user passwords";
    #   serviceConfig = {
    #     Type = "oneshot";
    #     ExecStart = "${pkgs.mysql}/bin/mysql -f /tmp/detsys-vault/set-passwords.sql";
    #     User = "mysql";
    #   };
    #   after = [ "mysql.service" ];
    #   wantedBy = [ "multi-user.target" ];
    #   preStart = "echo 'Preparing to set MySQL passwords'";
    # };

    # campground.services.vault-agent.services.set-mysql-passwords = {
    #   settings = {
    #     vault.address = cfg.vault-address;
    #     auto_auth = {
    #       method = [{
    #         type = "approle";
    #         config = {
    #           role_id_file_path = cfg.role-id;
    #           secret_id_file_path = cfg.secret-id;
    #           remove_secret_id_file_after_reading = false;
    #         };
    #       }];
    #     };
    #   };
    #   secrets = {
    #     file = {
    #       files = {
    #         "set-passwords.sql" = {
    #           text = builtins.concatStringsSep "\n" (map (db: ''
    #             {{ with secret "${cfg.vault-path}" }}
    #             SET PASSWORD FOR '${db.user}'@'localhost' = PASSWORD('{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.${db.user} }}{{ else }}{{ .Data.data.${db.user} }}{{ end }}');
    #             {{ end }}
    #           '') cfg.databases);
    #           permissions = "0600";
              # change-action = "restart";
    #         };
    #       };
    #     };
    #   };
    # };
  };
}
