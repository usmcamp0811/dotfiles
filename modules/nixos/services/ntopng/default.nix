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

    disableLogin = mkOption {
      type = types.bool;
      default = false;
      description = "Disable ntopng login requirement (WARNING: Insecure, only use on trusted networks).";
    };

    adminPassword = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Admin password for API configuration (only used for auto-configuration via REST API).";
    };

    adminPasswordFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Path to file containing admin password for API configuration. Preferred over adminPassword to keep secrets out of nix store.";
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
          ${optionalString cfg.disableLogin "--disable-login=1"}
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

    # Configure ntopng via REST API after startup
    systemd.services.ntopng-api-config = mkIf (cfg.hostPools != {} || cfg.customHosts != {}) {
      description = "ntopng REST API configuration";
      after = [ "ntopng.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        Restart = "on-failure";
        RestartSec = "10s";
      };
      script = let
        # Generate pool configuration script
        poolsScript = concatStringsSep "\n" (
          mapAttrsToList (poolName: poolCfg: ''
            # Create pool: ${poolName}
            POOL_ID=$(${pkgs.curl}/bin/curl -s $AUTH_STR \
              "http://localhost:${toString cfg.port}/lua/rest/v2/add/pool.lua?pool_name=${lib.escapeShellArg poolName}" \
              | ${pkgs.jq}/bin/jq -r '.rsp.pool_id // empty')

            if [ -n "$POOL_ID" ]; then
              echo "Created pool '${poolName}' with ID: $POOL_ID"
              ${concatMapStringsSep "\n" (member: ''
                # Add member ${member} to pool
                ${pkgs.curl}/bin/curl -s $AUTH_STR \
                  "http://localhost:${toString cfg.port}/lua/rest/v2/bind/pool/member.lua?pool=$POOL_ID&member=${lib.escapeShellArg member}" \
                  > /dev/null
              '') poolCfg.members}
            else
              echo "Failed to create pool '${poolName}'"
            fi
          '') cfg.hostPools
        );

        # Generate custom hosts script
        hostsScript = concatStringsSep "\n" (
          mapAttrsToList (addr: hostCfg: ''
            # Set custom name for ${addr}
            ${pkgs.curl}/bin/curl -s $AUTH_STR \
              -X POST \
              "http://localhost:${toString cfg.port}/lua/rest/v2/set/host/alias.lua" \
              -d "host=${lib.escapeShellArg addr}&custom_name=${lib.escapeShellArg hostCfg.name}" \
              > /dev/null
          '') cfg.customHosts
        );
      in ''
        # Determine authentication
        AUTH_STR=""
        ${optionalString (!cfg.disableLogin) ''
          if [ -n "${optionalString (cfg.adminPasswordFile != null) cfg.adminPasswordFile}" ]; then
            # Read password from file
            ADMIN_PASSWORD=$(cat ${cfg.adminPasswordFile} | tr -d '\n')
            AUTH_STR="-u admin:$ADMIN_PASSWORD"
          elif [ -n "${optionalString (cfg.adminPassword != null) cfg.adminPassword}" ]; then
            # Use password from config (not recommended)
            AUTH_STR="-u admin:${cfg.adminPassword}"
          else
            echo "ERROR: Login is enabled but no adminPassword or adminPasswordFile configured"
            exit 1
          fi
        ''}

        # Wait for ntopng to be ready
        for i in {1..30}; do
          if ${pkgs.curl}/bin/curl -s -f http://localhost:${toString cfg.port}/ > /dev/null 2>&1; then
            echo "ntopng is ready"
            break
          fi
          echo "Waiting for ntopng to start... ($i/30)"
          sleep 2
        done

        ${optionalString (cfg.hostPools != {}) poolsScript}
        ${optionalString (cfg.customHosts != {}) hostsScript}

        echo "ntopng configuration complete"
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
