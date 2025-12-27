{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.services.ntopng;
in {
  options.fmf.services.ntopng = {
    enable = mkEnableOption "ntopng network traffic monitoring";

    port = mkOpt types.port 3000 "The HTTP port for ntopng web interface.";

    interfaces = mkOption {
      type = types.listOf types.str;
      default = ["eth0"];
      description = "Network interfaces to monitor.";
      example = literalExpression ''["eth0" "wlan0"]'';
    };

    dataDir = mkOpt types.str "/var/lib/ntopng" "Directory for ntopng data files.";

    dumpFlows = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to dump flows to disk.";
    };

    localNetworks = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "List of local networks in CIDR notation.";
      example = literalExpression ''["192.168.1.0/24" "10.0.0.0/8"]'';
    };

    redis = {
      host = mkOpt types.str "localhost" "Redis server host.";

      port = mkOpt types.port 6379 "Redis server port.";

      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Whether to use Redis for data persistence.";
      };
    };

    extraConfig = mkOption {
      type = types.attrs;
      default = {};
      description = "Additional ntopng configuration options as key-value pairs.";
      example = literalExpression ''
        {
          "--disable-login" = "1";
          "--community" = true;
        }
      '';
    };

    extraFlags = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Extra command-line flags to pass to ntopng.";
      example = literalExpression ''["--disable-autologout" "--disable-login"]'';
    };

    vault = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Whether to enable Vault integration for secrets management.";
      };

      secret-id = mkOpt types.str
        config.fmf.services.vault-agent.settings.vault.secret-id
        "Absolute path to the Vault secret-id";

      vault-path = mkOpt types.str
        "secret/campground/ntopng"
        "The Vault path to the KV containing the ntopng secrets.";

      kvVersion = mkOpt types.str "v2" "KV Secrets Engine version (v1 or v2).";
    };
  };

  config = mkIf cfg.enable {
    services.ntopng = {
      enable = true;

      extraConfig = let
        baseConfig = ''
          --http-port=${toString cfg.port}
          --data-dir=${cfg.dataDir}
          ${concatMapStringsSep "\n" (iface: "--interface=${iface}") cfg.interfaces}
          ${optionalString (cfg.localNetworks != []) "--local-networks=${concatStringsSep "," cfg.localNetworks}"}
          ${optionalString cfg.dumpFlows "--dump-flows"}
          ${optionalString cfg.redis.enable "--redis=${cfg.redis.host}:${toString cfg.redis.port}"}
          ${concatStringsSep "\n" cfg.extraFlags}
        '';
      in baseConfig;
    };

    # Enable Redis if configured
    services.redis.servers.ntopng = mkIf cfg.redis.enable {
      enable = true;
      port = cfg.redis.port;
      bind = cfg.redis.host;
    };

    # Create data directory
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0750 ntopng ntopng -"
    ];

    # Open firewall port
    # networking.firewall.allowedTCPPorts = [ cfg.port ];

    # Vault integration for secrets
    fmf.services.vault-agent = mkIf cfg.vault.enable {
      enable = true;
      services.ntopng = {
        settings = {
          vault = {
            address = config.fmf.services.vault-agent.settings.vault.address;
            secret_id_file_path = cfg.vault.secret-id;
            remove_secret_id_file_after_reading = false;
          };
        };

        secrets = {
          file.files = {
            ntopng-admin-password = {
              text = ''{{ with secret "${cfg.vault.vault-path}" }}{{ if eq "${cfg.vault.kvVersion}" "v1" }}{{ .Data.admin_password }}{{ else }}{{ .Data.data.admin_password }}{{ end }}{{ end }}'';
              path = "/var/lib/ntopng/admin-password";
              owner = "ntopng";
              group = "ntopng";
              permissions = "0400";
            };

            ntopng-license = {
              text = ''{{ with secret "${cfg.vault.vault-path}" }}{{ if eq "${cfg.vault.kvVersion}" "v1" }}{{ .Data.license_key }}{{ else }}{{ .Data.data.license_key }}{{ end }}{{ end }}'';
              path = "/var/lib/ntopng/license.key";
              owner = "ntopng";
              group = "ntopng";
              permissions = "0400";
            };
          };

          environment.templates = {
            ntopng-env = {
              text = ''
                NTOPNG_ADMIN_USER={{ with secret "${cfg.vault.vault-path}" }}{{ if eq "${cfg.vault.kvVersion}" "v1" }}{{ .Data.admin_user }}{{ else }}{{ .Data.data.admin_user }}{{ end }}{{ end }}
                NTOPNG_ADMIN_PASSWORD={{ with secret "${cfg.vault.vault-path}" }}{{ if eq "${cfg.vault.kvVersion}" "v1" }}{{ .Data.admin_password }}{{ else }}{{ .Data.data.admin_password }}{{ end }}{{ end }}
              '';
              path = "/var/lib/ntopng/env";
              owner = "ntopng";
              group = "ntopng";
              permissions = "0400";
            };
          };
        };
      };
    };
  };
}
