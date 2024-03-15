{ config, lib, pkgs, ... }:

with lib;
with lib.campground;
let 
  cfg = config.campground.services.keycloak;
in
{
  options.campground.services.keycloak = with types; {
    enable = mkBoolOpt false "Whether or not to enable keycloak.";
    port = mkOpt int 22547 "Port to listen on";
    hostname = mkOpt str "aicampground.com" "The hostname part of the public URL used as base for all frontend requests.";

    role-id = mkOpt str config.campground.services.vault-agent.settings.vault.role-id "Absolute path to the Vault role-id";
    secret-id = mkOpt str config.campground.services.vault-agent.settings.vault.secret-id "Absolute path to the Vault secret-id";
    vault-path = mkOpt str "secret/campground/keycloak" "The Vault path to the KV containing the KVs that are for each database";
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
  };

  config = mkIf cfg.enable {

    environment.systemPackages = [ pkgs.docker ];

    services.nginx = {
      enable = true;

      virtualHosts = {
        "keycloak.lan" = {
          listen = [ { addr = "0.0.0.0"; port = cfg.port; } ];  # Specify the port here
          locations = {
            "/cloak/" = {
              proxyPass = "http://localhost:${toString config.services.keycloak.settings.http-port}/cloak/";
            };
          };
        };
      };
    };

    systemd.services.keycloakPasswordFile = {
      description = "Create Keycloak db password file";
      serviceConfig = {
        Type = "oneshot";
        User = "root";  # Use the root user to create the folder and set permissions
        ExecStartPre = "${pkgs.coreutils}/bin/chown root:root /var/lib/vault"; # Set folder ownership to root
        ExecStart = "${pkgs.coreutils}/bin/cp /tmp/detsys-vault/keycloak-db.pass /var/lib/vault/keycloak-db.pass";
        ExecStartPost = "${pkgs.coreutils}/bin/chown keycloak:keycloak /var/lib/vault/keycloak-db.pass"; # Change file ownership to vaultwarden
      };
      wantedBy = [ "multi-user.target" ];
      before = [ "keycloak.service" ];
    };

    services.postgresql.enable = true;

    services.keycloak = {
      enable = true;

      database = {
        type = "postgresql";
        createLocally = true;
        username = "keycloak";
        passwordFile = "/var/lib/vault/keycloak-db.pass";
      };

      settings = {
        hostname = cfg.hostname;
        http-relative-path = "/cloak";
        http-port = 9323;
        proxy = "passthrough";
        http-enabled = true;
      };
    };

    campground.services.vault-agent.services.keycloakPasswordFile = {
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
            "keycloak-db.pass" = {
              text = ''{{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.dbpass }}{{ else }}{{ .Data.data.dbpass }}{{ end }}{{ end }}'';
              permissions = "0600";
              change-action = "restart";
            };
          };
        };
      };
    };
  };
}

