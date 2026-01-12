{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.services.ntopng;

  # Build a line-based ntopng.conf (ntopng accepts a file that contains CLI flags, one per line)
  ntopngConfText = let
    ifaceLines = concatMapStringsSep "\n" (iface: "--interface=${iface}") cfg.interfaces;

    # Render additional key/value style options as `--flag=value` (or `--flag` if value == true)
    extraKvLines = concatStringsSep "\n" (mapAttrsToList (
        k: v:
          if v == true
          then "${k}"
          else "${k}=${toString v}"
      )
      cfg.extraConfig);
  in ''
    --http-port=${toString cfg.port}
    --data-dir=${cfg.dataDir}
    ${optionalString (cfg.redis.enable) "--redis=${cfg.redis.host}:${toString cfg.redis.port}"}
    ${optionalString (cfg.localNetworks != []) "--local-networks=${concatStringsSep "," cfg.localNetworks}"}
    ${optionalString cfg.dumpFlows "--dump-flows"}
    ${optionalString cfg.disableLogin "--disable-login=1"}
    ${ifaceLines}
    ${extraKvLines}
    ${concatStringsSep "\n" cfg.extraFlags}
  '';

  ntopngConfFile = pkgs.writeText "ntopng.conf" ntopngConfText;

  # Helper script for URL encoding in the systemd oneshot API-config unit
  urlenc = "${pkgs.python3}/bin/python -c 'import sys,urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=\"\"))'";
  curl = "${pkgs.curl}/bin/curl";
  jq = "${pkgs.jq}/bin/jq";
in {
  options.fmf.services.ntopng = {
    enable = mkEnableOption "ntopng network traffic monitoring";

    port = mkOpt types.port 3000 "The HTTP port for the ntopng web interface.";

    interfaces = mkOption {
      type = types.listOf types.str;
      default = ["eth0"];
      description = "Network interfaces to monitor.";
      example = literalExpression ''["eth0" "eth1"]'';
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
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Whether to use Redis for data persistence.";
      };

      host = mkOpt types.str "127.0.0.1" "Redis server host.";

      port = mkOpt types.port 6379 "Redis server port.";
    };

    # Additional ntopng flags expressed as an attrset, rendered as `--flag=value` or `--flag` if true.
    extraConfig = mkOption {
      type = types.attrs;
      default = {};
      description = "Additional ntopng configuration options as key-value pairs.";
      example = literalExpression ''
        {
          "--dns-mode" = 1;
          "--disable-autologout" = true;
        }
      '';
    };

    extraFlags = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Extra command-line flags (one per entry) to pass to ntopng.";
      example = literalExpression ''["--ndpi-protocols" "--verbose"]'';
    };

    disableLogin = mkOption {
      type = types.bool;
      default = false;
      description = "Disable ntopng login requirement (WARNING: insecure; only on trusted networks).";
    };

    adminPassword = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Admin password for API configuration (not recommended; prefer adminPasswordFile).";
    };

    adminPasswordFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Path to a file containing the admin password for API configuration.";
    };

    hostPools = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          members = mkOption {
            type = types.listOf types.str;
            default = [];
            description = "IPs, CIDRs, or MACs in this pool.";
            example = literalExpression ''["10.8.20.0/24" "AA:BB:CC:DD:EE:FF"]'';
          };
          recipients = mkOption {
            type = types.listOf types.str;
            default = [];
            description = "Alert recipients for this pool.";
          };
        };
      });
      default = {};
      description = "Host pools configuration. Pool name is the attribute name.";
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
            description = "Optional icon name for this host (if supported by your ntopng build/UI).";
          };
        };
      });
      default = {};
      description = "Custom host names and metadata. Key is IP or MAC.";
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
        "secret/campground/ntopng"
        "The Vault path to the KV containing the ntopng secrets.";

      kvVersion = mkOpt types.str "v2" "KV Secrets Engine version (v1 or v2).";
    };
  };

  config = mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = [
      cfg.port
    ];
    services.ntopng = {
      enable = true;

      # We explicitly pass a config file rather than relying on the default interface behavior.
      # The upstream NixOS module supports a "configFile" style; if yours doesn’t,
      # swap this to the appropriate option your base module exposes.
      #
      # Common patterns are either:
      #   services.ntopng.configFile = ntopngConfFile;
      # or:
      #   services.ntopng.extraConfig = builtins.readFile ntopngConfFile;
      #
      # This module uses the latter (string), since it's widely supported.
      extraConfig = builtins.readFile ntopngConfFile;

      # Prevent "any" being implicitly added by some wrappers.
      interfaces = [];
    };

    # Redis (separate instance) if requested
    services.redis.servers.ntopng = mkIf cfg.redis.enable {
      enable = true;
      port = cfg.redis.port;
      bind = cfg.redis.host;

      save = [
        [900 1]
        [300 10]
        [60 10000]
      ];

      settings = {
        dir = "/var/lib/redis-ntopng";
        dbfilename = "dump.rdb";
        appendonly = "yes";
        appendfilename = "appendonly.aof";
      };
    };

    # Ensure dirs exist with sane perms (especially useful when using virtiofs mounts)
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0750 ntopng ntopng -"
      "d /var/lib/redis-ntopng 0750 redis redis -"
    ];

    # Provision host pools + custom hostnames using REST API after ntopng starts
    #
    # IMPORTANT: ntopng REST endpoints can differ by version/edition.
    # This unit logs every response so you can see exactly what fails.
    systemd.services.ntopng-api-config = mkIf (cfg.hostPools != {} || cfg.customHosts != {}) {
      description = "ntopng REST API configuration";
      after = ["ntopng.service" "network-online.target"];
      wants = ["network-online.target"];
      wantedBy = ["multi-user.target"];

      serviceConfig = {
        Type = "oneshot";
        Restart = "on-failure";
        RestartSec = "10s";
      };

      script = let
        poolsScript = concatStringsSep "\n" (mapAttrsToList (poolName: poolCfg: ''
            echo "==> Creating pool: ${poolName}"

            POOL_NAME_ENC=$(${urlenc} ${lib.escapeShellArg poolName})

            # Create pool (endpoint may differ by ntopng version; we log response)
            RESP="$(${curl} -sS --fail $AUTH_STR \
              "http://127.0.0.1:${toString cfg.port}/lua/rest/v2/add/pool.lua?pool_name=$POOL_NAME_ENC" \
              || true)"

            echo "Pool create response: $RESP"

            POOL_ID="$(echo "$RESP" | ${jq} -r '.rsp.pool_id // empty' 2>/dev/null || true)"

            if [ -z "$POOL_ID" ]; then
              echo "ERROR: Failed to create pool '${poolName}'. Response: $RESP" >&2
              exit 1
            fi

            echo "Created pool '${poolName}' with ID: $POOL_ID"

            ${concatMapStringsSep "\n" (member: ''
                echo "  -> Adding member: ${member}"
                MEMBER_ENC=$(${urlenc} ${lib.escapeShellArg member})

                for attempt in 1 2 3 4 5; do
                  RESP2="$(${curl} -sS --fail $AUTH_STR \
                    "http://127.0.0.1:${toString cfg.port}/lua/rest/v2/bind/pool/member.lua?pool=$POOL_ID&member=$MEMBER_ENC" \
                    || true)"

                  if [ -n "$RESP2" ]; then
                    echo "     Member add response: $RESP2"
                  fi

                  # If curl succeeded, it would have --fail’d on HTTP errors; treat non-empty response as “done”
                  if ${curl} -sS --fail $AUTH_STR \
                    "http://127.0.0.1:${toString cfg.port}/lua/rest/v2/bind/pool/member.lua?pool=$POOL_ID&member=$MEMBER_ENC" \
                    >/dev/null 2>&1; then
                    break
                  fi

                  echo "     (attempt $attempt failed, retrying...)"
                  sleep 2
                  if [ "$attempt" = "5" ]; then
                    echo "ERROR: Failed to add member '${member}' to pool '${poolName}'" >&2
                    exit 1
                  fi
                done
              '')
              poolCfg.members}
          '')
          cfg.hostPools);

        hostsScript = concatStringsSep "\n" (mapAttrsToList (addr: hostCfg: ''
            echo "==> Setting host alias for ${addr} -> ${hostCfg.name}"

            HOST_ENC=$(${urlenc} ${lib.escapeShellArg addr})
            NAME_ENC=$(${urlenc} ${lib.escapeShellArg hostCfg.name})

            RESP="$(${curl} -sS --fail $AUTH_STR \
              -X POST \
              "http://127.0.0.1:${toString cfg.port}/lua/rest/v2/set/host/alias.lua" \
              -H "Content-Type: application/x-www-form-urlencoded" \
              --data "host=$HOST_ENC&custom_name=$NAME_ENC" \
              || true)"

            echo "Host alias response: $RESP"
          '')
          cfg.customHosts);
      in ''
        set -euo pipefail

        AUTH_STR=""
        ${optionalString (!cfg.disableLogin) (
          if cfg.adminPasswordFile != null
          then ''
            ADMIN_PASSWORD="$(tr -d '\n' < ${cfg.adminPasswordFile})"
            AUTH_STR="-u admin:$ADMIN_PASSWORD"
          ''
          else if cfg.adminPassword != null
          then ''
            AUTH_STR="-u admin:${cfg.adminPassword}"
          ''
          else ''
            echo "ERROR: Login is enabled but no adminPassword/adminPasswordFile configured" >&2
            exit 1
          ''
        )}

        echo "Waiting for ntopng REST to be ready..."
        for i in $(seq 1 60); do
          if ${curl} -sS --fail $AUTH_STR \
            "http://127.0.0.1:${toString cfg.port}/lua/rest/v2/get/system/status.lua" \
            >/dev/null 2>&1; then
            echo "ntopng REST is ready"
            break
          fi
          sleep 2
          if [ "$i" = "60" ]; then
            echo "ERROR: ntopng REST did not become ready" >&2
            exit 1
          fi
        done

        ${optionalString (cfg.hostPools != {}) poolsScript}
        ${optionalString (cfg.customHosts != {}) hostsScript}

        echo "ntopng configuration complete"
      '';
    };

    # Vault integration (optional): provides a password file you can point adminPasswordFile at
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
              text = ''
                {{ with secret "${cfg.vault.vault-path}" -}}
                {{- if eq "${cfg.vault.kvVersion}" "v1" -}}
                {{ .Data.admin_password }}
                {{- else -}}
                {{ .Data.data.admin_password }}
                {{- end -}}
                {{- end -}}
              '';
              permissions = "0400";
            };
          };
        };
      };
    };
  };
}
