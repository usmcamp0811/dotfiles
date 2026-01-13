{ host ? ""
, options
, config
, lib
, pkgs
, ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.services.authentik;
  authentikDir = "/var/lib/authentik";
in
{
  options.fmf.services.authentik = with types; {
    enable =
      mkBoolOpt false "Whether or not to enable Authentik configuration.";
    port = mkOpt int 8434 "Port to Host the Authentik server.";
    avatars = mkOpt str "gravatar" "Avatars to use?";

    role-id =
      mkOpt str config.fmf.services.vault-agent.settings.vault.role-id
        "Absolute path to the Vault role-id";
    secret-id =
      mkOpt str config.fmf.services.vault-agent.settings.vault.secret-id
        "Absolute path to the Vault secret-id";
    vault-path =
      mkOpt str "secret/campground/authentik"
        "The Vault path to the KV containing the KVs that are for each database";
    kvVersion = mkOption {
      type = enum [ "v1" "v2" ];
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
      enableTCPIP = true;
      backupEnable = true;
      backupLocation = "/persist/postgresqlBackups/";
      databases = [
        {
          name = "authentik";
          user = "authentik";
        }
      ];
      package = pkgs.postgresql_14; # Ensure compatibility with Authentik
      extraPlugins = [ pkgs.postgresql14Packages.timescaledb ];
    };
    services.authentik = {
      enable = true;
      environmentFile = "${authentikDir}/environmentFile";
      settings = {
        disable_startup_analytics = true;
        avatars = cfg.avatars;
        AUTHENTIK_OUTPOST_URL = "https://auth.aicampground.com";
        AUTHENTIK_DEFAULT_USER_SETTINGS__PATH = "/";
        AUTHENTIK_INSECURE = true;
        USE_X_FORWARDED_HOST = true;
        SECURE_PROXY_SSL_HEADER = "HTTP_X_FORWARDED_PROTO,https";
      };
    };
    services.authentik-ldap = {
      enable = true;
      environmentFile = "${authentikDir}/environmentFile";
    };

    networking.firewall.allowedTCPPorts = [ cfg.port ];

    systemd.services.authentikSecrets = {
      description = "Get Authentik Secrets";
      serviceConfig = {
        Type = "oneshot";
        User = "root";
      };
      script = ''
        mkdir -p ${authentikDir}
        ${pkgs.coreutils}/bin/cp /tmp/detsys-vault/environmentFile ${authentikDir}/environmentFile
      '';
      wantedBy = [ "multi-user.target" ];
      before = [
        "authentik-migrate.service"
        "authentik-worker.service"
        "authentik.service"
        "authentik-ldap.service"
        "authentik-radius.service"
      ];
    };
    fmf.services.vault-agent.services = {
      authentikSecrets = {
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
              "environmentFile" = {
                text = ''
                  AUTHENTIK_HOST=https://auth.aicampground.com
                  AUTHENTIK_TOKEN={{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.AUTHENTIK_TOKEN }}{{ else }}{{ .Data.data.AUTHENTIK_TOKEN }}{{ end }}{{ end }}
                  AUTHENTIK_SECRET_KEY={{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.AUTHENTIK_SECRET_KEY }}{{ else }}{{ .Data.data.AUTHENTIK_SECRET_KEY }}{{ end }}{{ end }}
                  AUTHENTIK_LISTEN__HTTP=0.0.0.0:${toString cfg.port}
                  AUTHENTIK_EMAIL__HOST={{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.AUTHENTIK_EMAIL__HOST }}{{ else }}{{ .Data.data.AUTHENTIK_EMAIL__HOST }}{{ end }}{{ end }}
                  AUTHENTIK_EMAIL__PORT={{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.AUTHENTIK_EMAIL__PORT }}{{ else }}{{ .Data.data.AUTHENTIK_EMAIL__PORT }}{{ end }}{{ end }}
                  AUTHENTIK_EMAIL__USERNAME={{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.AUTHENTIK_EMAIL__USERNAME }}{{ else }}{{ .Data.data.AUTHENTIK_EMAIL__USERNAME }}{{ end }}{{ end }}
                  AUTHENTIK_EMAIL__PASSWORD={{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.AUTHENTIK_EMAIL__PASSWORD }}{{ else }}{{ .Data.data.AUTHENTIK_EMAIL__PASSWORD }}{{ end }}{{ end }}
                  AUTHENTIK_EMAIL__USE_TLS={{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.AUTHENTIK_EMAIL__USE_TLS }}{{ else }}{{ .Data.data.AUTHENTIK_EMAIL__USE_TLS }}{{ end }}{{ end }}
                  AUTHENTIK_EMAIL__USE_SSL={{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.AUTHENTIK_EMAIL__USE_SSL }}{{ else }}{{ .Data.data.AUTHENTIK_EMAIL__USE_SSL }}{{ end }}{{ end }}
                  AUTHENTIK_EMAIL__TIMEOUT={{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.AUTHENTIK_EMAIL__TIMEOUT }}{{ else }}{{ .Data.data.AUTHENTIK_EMAIL__TIMEOUT }}{{ end }}{{ end }}
                  AUTHENTIK_EMAIL__FROM={{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.AUTHENTIK_EMAIL__FROM }}{{ else }}{{ .Data.data.AUTHENTIK_EMAIL__FROM }}{{ end }}{{ end }}
                '';
                permissions = "0600";
                change-action = "restart";
              };
            };
          };
        };
      };
    };
  };
}
