{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.services.librenms;
in {
  options.fmf.services.librenms = {
    enable = mkEnableOption "LibreNMS network monitoring";

    package = mkOpt types.package pkgs.librenms "The LibreNMS package to use.";

    hostname = mkOpt types.str "librenms.local" "The hostname for LibreNMS.";

    port = mkOpt types.port 8080 "The port to run LibreNMS on.";

    database = {
      host = mkOpt types.str "localhost" "Database host.";

      port = mkOpt types.port 3306 "Database port.";

      name = mkOpt types.str "librenms" "Database name.";

      user = mkOpt types.str "librenms" "Database user.";

      passwordFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to file containing the database password.";
      };

      createLocally = mkOption {
        type = types.bool;
        default = true;
        description = "Whether to create a local MariaDB database automatically.";
      };
    };

    poolSize = mkOpt types.int 16 "PHP-FPM pool size (number of workers).";

    enableSyslog = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to enable syslog integration.";
    };

    enableBilling = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to enable billing module.";
    };

    enableDistributedPoller = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to enable distributed poller.";
    };

    extraConfig = mkOption {
      type = types.attrs;
      default = {};
      description = "Additional LibreNMS configuration options.";
      example = literalExpression ''
        {
          enable_syslog = true;
          enable_billing = true;
          discovery_threads = 4;
        }
      '';
    };

    vault = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Whether to enable Vault integration for secrets management.";
      };

      secret-id =
        mkOpt types.str
        config.fmf.services.vault-agent.settings.vault.secret-id
        "Absolute path to the Vault secret-id";

      vault-path =
        mkOpt types.str
        "secret/campground/librenms"
        "The Vault path to the KV containing the LibreNMS secrets.";

      kvVersion = mkOpt types.str "v2" "KV Secrets Engine version (v1 or v2).";
    };
  };

  config = mkIf cfg.enable {
    services.librenms = {
      enable = true;
      package = cfg.package;
      hostname = cfg.hostname;

      database = {
        host = cfg.database.host;
        port = cfg.database.port;
        database = cfg.database.name;
        username = cfg.database.user;
        passwordFile = cfg.database.passwordFile;
        createLocally = cfg.database.createLocally;
      };

      poolConfig = {
        "pm" = "dynamic";
        "pm.max_children" = toString cfg.poolSize;
        "pm.start_servers" = toString (cfg.poolSize / 4);
        "pm.min_spare_servers" = toString (cfg.poolSize / 4);
        "pm.max_spare_servers" = toString (cfg.poolSize / 2);
      };

      # Override nginx config to avoid the enableSSL bug
      nginx = {
        listen = [
          {
            addr = "0.0.0.0";
            port = cfg.port;
          }
        ];
      };
    };

    # Open firewall port
    # networking.firewall.allowedTCPPorts = [ cfg.port ];

    # Vault integration for secrets
    fmf.services.vault-agent = mkIf cfg.vault.enable {
      enable = true;
      services.librenms = {
        settings = {
          vault = {
            address = config.fmf.services.vault-agent.settings.vault.address;
            secret_id_file_path = cfg.vault.secret-id;
            remove_secret_id_file_after_reading = false;
          };
        };

        secrets = {
          file.files = {
            librenms-db-password = {
              text = ''{{ with secret "${cfg.vault.vault-path}" }}{{ if eq "${cfg.vault.kvVersion}" "v1" }}{{ .Data.db_password }}{{ else }}{{ .Data.data.db_password }}{{ end }}{{ end }}'';
              permissions = "0400";
            };
          };

          environment.templates = {
            librenms-env = {
              text = ''
                LIBRENMS_ADMIN_USER={{ with secret "${cfg.vault.vault-path}" }}{{ if eq "${cfg.vault.kvVersion}" "v1" }}{{ .Data.admin_user }}{{ else }}{{ .Data.data.admin_user }}{{ end }}{{ end }}
                LIBRENMS_ADMIN_PASSWORD={{ with secret "${cfg.vault.vault-path}" }}{{ if eq "${cfg.vault.kvVersion}" "v1" }}{{ .Data.admin_password }}{{ else }}{{ .Data.data.admin_password }}{{ end }}{{ end }}
                LIBRENMS_ADMIN_EMAIL={{ with secret "${cfg.vault.vault-path}" }}{{ if eq "${cfg.vault.kvVersion}" "v1" }}{{ .Data.admin_email }}{{ else }}{{ .Data.data.admin_email }}{{ end }}{{ end }}
              '';
            };
          };
        };
      };
    };
  };
}
