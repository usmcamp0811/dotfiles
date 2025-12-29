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

    hostPools = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          members = mkOption {
            type = types.listOf types.str;
            default = [];
            description = "List of IP addresses, networks (CIDR), or MAC addresses in this pool.";
            example = literalExpression ''["192.168.1.10" "192.168.1.0/24" "AA:BB:CC:DD:EE:FF"]'';
          };
          recipients = mkOption {
            type = types.listOf types.str;
            default = [];
            description = "List of alert recipients for this pool.";
          };
        };
      });
      default = {};
      description = "Host pools configuration. Pool name is the attribute name.";
      example = literalExpression ''
        {
          "IoT Devices" = {
            members = ["10.8.20.0/24"];
            recipients = [];
          };
          "Servers" = {
            members = ["10.8.0.10" "10.8.0.11"];
            recipients = [];
          };
        }
      '';
    };

    customHosts = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          name = mkOption {
            type = types.str;
            description = "Custom name for this host.";
          };
          icon = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "Icon name for this host.";
          };
        };
      });
      default = {};
      description = "Custom host names and metadata. Key is IP or MAC address.";
      example = literalExpression ''
        {
          "10.8.0.1" = {
            name = "Router";
            icon = "router";
          };
          "10.8.0.2" = {
            name = "AdGuard DNS";
            icon = "shield";
          };
        }
      '';
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

  config = mkIf cfg.enable (let
    # Generate host pools configuration file
    hostPoolsConfig = pkgs.writeText "host_pools.conf" (
      concatStringsSep "\n" (
        mapAttrsToList (poolName: poolCfg:
          "${poolName}@${concatStringsSep "," poolCfg.members}@${concatStringsSep "," poolCfg.recipients}"
        ) cfg.hostPools
      )
    );

    # Generate custom hosts configuration (JSON format)
    customHostsConfig = pkgs.writeText "custom_hosts.json" (
      builtins.toJSON (
        mapAttrs (addr: hostCfg: {
          name = hostCfg.name;
        } // optionalAttrs (hostCfg.icon != null) {
          icon = hostCfg.icon;
        }) cfg.customHosts
      )
    );
  in {
    services.ntopng = {
      enable = true;

      # Disable the default interface to prevent "any" from being added
      interfaces = [];

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

      # Persist data to disk
      save = [
        [900 1]    # Save after 900 seconds if at least 1 key changed
        [300 10]   # Save after 300 seconds if at least 10 keys changed
        [60 10000] # Save after 60 seconds if at least 10000 keys changed
      ];

      settings = {
        dir = "/var/lib/redis-ntopng";
        dbfilename = "dump.rdb";
        appendonly = "yes";
        appendfilename = "appendonly.aof";
      };
    };

    # Create data directories
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0750 ntopng ntopng -"
      "d /var/lib/redis-ntopng 0750 redis redis -"
    ];

    # Copy configuration files to data directory
    systemd.services.ntopng-config = mkIf (cfg.hostPools != {} || cfg.customHosts != {}) {
      description = "ntopng configuration setup";
      wantedBy = [ "ntopng.service" ];
      before = [ "ntopng.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = "ntopng";
        Group = "ntopng";
      };
      script = ''
        ${optionalString (cfg.hostPools != {}) ''
          mkdir -p ${cfg.dataDir}
          cp ${hostPoolsConfig} ${cfg.dataDir}/host_pools.conf
          chown ntopng:ntopng ${cfg.dataDir}/host_pools.conf
          chmod 640 ${cfg.dataDir}/host_pools.conf
        ''}
        ${optionalString (cfg.customHosts != {}) ''
          mkdir -p ${cfg.dataDir}
          cp ${customHostsConfig} ${cfg.dataDir}/custom_hosts.json
          chown ntopng:ntopng ${cfg.dataDir}/custom_hosts.json
          chmod 640 ${cfg.dataDir}/custom_hosts.json
        ''}
      '';
    };

    # Open firewall port
    # networking.firewall.allowedTCPPorts = [ cfg.port ];

    # Vault integration for secrets
    fmf.services.vault-agent = mkIf cfg.vault.enable {
      enable = true;
      services.ntopng = {
        settings = {
          vault.address = config.fmf.services.vault-agent.settings.vault.address;
          auto_auth.method = [
            {
              type = "approle";
              config = {
                role_id_file_path = config.fmf.services.vault-agent.settings.vault.role-id;
                secret_id_file_path = cfg.vault.secret-id;
                remove_secret_id_file_after_reading = false;
              };
            }
          ];
        };

        secrets = {
          file.files = {
            ntopng-admin-password = {
              text = ''{{ with secret "${cfg.vault.vault-path}" }}{{ if eq "${cfg.vault.kvVersion}" "v1" }}{{ .Data.admin_password }}{{ else }}{{ .Data.data.admin_password }}{{ end }}{{ end }}'';
              permissions = "0400";
            };

            ntopng-license = {
              text = ''{{ with secret "${cfg.vault.vault-path}" }}{{ if eq "${cfg.vault.kvVersion}" "v1" }}{{ .Data.license_key }}{{ else }}{{ .Data.data.license_key }}{{ end }}{{ end }}'';
              permissions = "0400";
            };
          };

          environment.templates = {
            ntopng-env = {
              text = ''
                NTOPNG_ADMIN_USER={{ with secret "${cfg.vault.vault-path}" }}{{ if eq "${cfg.vault.kvVersion}" "v1" }}{{ .Data.admin_user }}{{ else }}{{ .Data.data.admin_user }}{{ end }}{{ end }}
                NTOPNG_ADMIN_PASSWORD={{ with secret "${cfg.vault.vault-path}" }}{{ if eq "${cfg.vault.kvVersion}" "v1" }}{{ .Data.admin_password }}{{ else }}{{ .Data.data.admin_password }}{{ end }}{{ end }}
              '';
            };
          };
        };
      };
    };
  });
}
