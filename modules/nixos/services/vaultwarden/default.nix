{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
let
  cfg = config.campground.services.vaultwarden;
in
{
  options.campground.services.vaultwarden = with types; {
    enable = mkBoolOpt false "Enable Vaultwarden;";
    role-id = mkOpt str config.campground.services.vault-agent.settings.vault.role-id "Absolute path to the Vault role-id";
    secret-id = mkOpt str config.campground.services.vault-agent.settings.vault.secret-id "Absolute path to the Vault secret-id";
    vault-path = mkOpt str "secret/campground/vaultwarden" "The Vault path to the KV containing the KVs that are for each database";
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

    services.vaultwarden = {
      enable = true;
      dbBackend = "postgresql";
      environmentFile = "/tmp/detsys-vault/vaultwarden.env";
    };

    services.nginx = {
      virtualHosts."bitwarden.lan" = {
        # useACMEHost = "thalheim.io";
        # forceSSL = true;
        extraConfig = ''
          client_max_body_size 128M;
        '';
        locations."/" = {
          proxyPass = "http://localhost:3011";
          proxyWebsockets = true;
        };
        locations."/notifications/hub" = {
          proxyPass = "http://localhost:3012";
          proxyWebsockets = true;
        };
        locations."/notifications/hub/negotiate" = {
          proxyPass = "http://localhost:3011";
          proxyWebsockets = true;
        };
      };
    };
    campground.services.vault-agent.services.vaultwarden = {
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
            "vaultwarden.env" = {
              text = ''
                {{ with secret "${cfg.vault-path}" }}
                {{ if eq "${cfg.kvVersion}" "v1" }}
                SMTP_FROM={{ .Data.SMTP_FROM }}
                ADMIN_TOKEN={{ .Data.ADMIN_TOKEN }}
                DATABASE_URL={{ .Data.DATABASE_URL }}
                DOMAIN={{ .Data.DOMAIN }}
                EMERGENCY_ACCESS_ALLOWED={{ .Data.EMERGENCY_ACCESS_ALLOWED }}
                EVENTS_DAYS_RETAIN={{ .Data.EVENTS_DAYS_RETAIN }}
                ORG_CREATION_USERS={{ .Data.ORG_CREATION_USERS }}
                ORG_EVENTS_ENABLED={{ .Data.ORG_EVENTS_ENABLED }}
                SIGNUPS_ALLOWED={{ .Data.SIGNUPS_ALLOWED }}
                SMTP_FROM_NAME={{ .Data.SMTP_FROM_NAME }}
                SMTP_HOST={{ .Data.SMTP_HOST }}
                SMTP_PASSWORD={{ .Data.SMTP_PASSWORD }}
                SMTP_PORT={{ .Data.SMTP_PORT }}
                SMTP_SECURITY={{ .Data.SMTP_SECURITY }}
                SMTP_TIMEOUT={{ .Data.SMTP_TIMEOUT }}
                SMTP_USERNAME={{ .Data.SMTP_USERNAME }}
                TZ={{ .Data.TZ }}
                {{ else }}
                SMTP_FROM={{ .Data.data.SMTP_FROM }}
                ADMIN_TOKEN={{ .Data.data.ADMIN_TOKEN }}
                DATABASE_URL={{ .Data.data.DATABASE_URL }}
                DOMAIN={{ .Data.data.DOMAIN }}
                EMERGENCY_ACCESS_ALLOWED={{ .Data.data.EMERGENCY_ACCESS_ALLOWED }}
                EVENTS_DAYS_RETAIN={{ .Data.data.EVENTS_DAYS_RETAIN }}
                ORG_CREATION_USERS={{ .Data.data.ORG_CREATION_USERS }}
                ORG_EVENTS_ENABLED={{ .Data.data.ORG_EVENTS_ENABLED }}
                SIGNUPS_ALLOWED={{ .Data.data.SIGNUPS_ALLOWED }}
                SMTP_FROM_NAME={{ .Data.data.SMTP_FROM_NAME }}
                SMTP_HOST={{ .Data.data.SMTP_HOST }}
                SMTP_PASSWORD={{ .Data.data.SMTP_PASSWORD }}
                SMTP_PORT={{ .Data.data.SMTP_PORT }}
                SMTP_SECURITY={{ .Data.data.SMTP_SECURITY }}
                SMTP_TIMEOUT={{ .Data.data.SMTP_TIMEOUT }}
                SMTP_USERNAME={{ .Data.data.SMTP_USERNAME }}
                TZ={{ .Data.data.TZ }}
                {{ end }}
                {{ end }}
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
