{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.services.vaultwarden;
in {
  options.fmf.services.vaultwarden = with types; {
    enable = mkBoolOpt false "Enable Vaultwarden;";
    port = mkOpt int 8989 "Port to expose Vaultwarden on";
    role-id =
      mkOpt str config.fmf.services.vault-agent.settings.vault.role-id
      "Absolute path to the Vault role-id";
    secret-id =
      mkOpt str config.fmf.services.vault-agent.settings.vault.secret-id
      "Absolute path to the Vault secret-id";
    vault-path =
      mkOpt str "secret/campground/vaultwarden"
      "The Vault path to the KV containing the KVs that are for each database";
    kvVersion = mkOption {
      type = enum ["v1" "v2"];
      default = "v2";
      description = "KV store version";
    };
    vault-address = mkOption {
      type = str;
      default = config.fmf.services.vault-agent.settings.vault.address;
      description = "The address of your Vault";
    };
  };

  config = mkIf cfg.enable {
    fmf.services.postgresql = {
      enable = true;
      authentication = [
        "local vaultwarden vaultwarden trust"
      ];
      databases = [
        {
          name = "vaultwarden";
          user = "vaultwarden";
        }
      ];
    };

    services.vaultwarden = {
      enable = true;
      dbBackend = "postgresql";
      environmentFile = "/var/lib/vault/vaultwarden.env";
    };

    services.nginx = {
      enable = true;
      virtualHosts."vaultwarden.lan" = {
        listen = [
          {
            addr = "0.0.0.0";
            port = cfg.port;
          }
        ]; # Specify the port here
        # useACMEHost = "thalheim.io";
        # forceSSL = true;
        # extraConfig = ''
        #   listen ${toString cfg.port};
        #   client_max_body_size 128M;
        # '';
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
    systemd.services.vaultwarden_env = {
      description = "Create Vaultwarden environment file";
      serviceConfig = {
        Type = "oneshot";
        User = "root"; # Use the root user to create the folder and set permissions
        ExecStartPre = "${pkgs.coreutils}/bin/chown root:root /var/lib/vault"; # Set folder ownership to root
        ExecStart = "${pkgs.coreutils}/bin/cp /tmp/detsys-vault/vaultwarden.env /var/lib/vault/vaultwarden.env";
        ExecStartPost = "${pkgs.coreutils}/bin/chown vaultwarden:vaultwarden /var/lib/vault/vaultwarden.env"; # Change file ownership to vaultwarden
      };
      wantedBy = ["multi-user.target"];
      before = ["vaultwarden.service"];
    };

    fmf.services.vault-agent.services.vaultwarden_env = {
      settings = {
        vault.address = cfg.vault-address;
        auto_auth = {
          method = [
            {
              type = "approle";
              config = {
                role_id_file_path = cfg.role-id;
                secret_id_file_path = cfg.secret-id;
                remove_secret_id_file_after_reading = false;
              };
            }
          ];
        };
      };
      secrets = {
        file = {
          files = {
            "vaultwarden.env" = {
              text = ''
                {{ with secret "${cfg.vault-path}" }}
                  WEBSOCKET_PORT=3012
                  ROCKET_PORT=3011
                                {{ if eq "${cfg.kvVersion}" "v1" }}
                  SMTP_FROM={{ .Data.SMTP_FROM }}
                  # ADMIN_TOKEN={{ .Data.ADMIN_TOKEN }}
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
                  # ADMIN_TOKEN={{ .Data.data.ADMIN_TOKEN }}
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
                  {{ end }}'';
              permissions = "0600";
              change-action = "restart";
            };
          };
        };
      };
    };
  };
}
