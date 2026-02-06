# modules/services/zeek.nix
{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.services.zeek;

  # Generate local.zeek with custom scripts
  localZeek = pkgs.writeText "local.zeek" ''
    @load policy/misc/stats

    ${optionalString cfg.enableJsonLogs ''
      @load policy/tuning/json-logs.zeek
    ''}

    ${optionalString (cfg.localNetworks != []) ''
      redef Site::local_nets = {
        ${concatMapStringsSep ",\n  " (net: "${net}") cfg.localNetworks}
      };
    ''}

    ${optionalString cfg.enableFileExtraction ''
      @load frameworks/files/extract-all-files
    ''}

    ${concatMapStringsSep "\n" (script: "@load ${script}") cfg.extraScripts}

    ${cfg.extraConfig}
  '';

  # Generate networks.cfg for local network definitions (optional utility)
  networksConfig = pkgs.writeText "networks.cfg" (
    if cfg.localNetworks != []
    then
      concatMapStringsSep "\n" (net: let
        parts = lib.splitString "/" net;
        addr = builtins.head parts;
      in "${net}       Network_${builtins.replaceStrings ["."] ["_"] addr}")
      cfg.localNetworks
    else "# No local networks defined\n"
  );

  unitNameForIface = iface: "zeek@${iface}";
in {
  options.fmf.services.zeek = {
    enable = mkEnableOption "Zeek Network Security Monitor";

    package = mkOpt types.package pkgs.zeek "The Zeek package to use.";

    interfaces = mkOption {
      type = types.listOf types.str;
      default = ["eth0"];
      description = "Network interfaces to monitor (one Zeek process per interface).";
      example = literalExpression ''["eth0" "eth1"]'';
    };

    logDir = mkOpt types.str "/var/lib/zeek/logs" "Directory for Zeek log files.";
    spoolDir = mkOpt types.str "/var/lib/zeek/spool" "Directory for Zeek spool/state files.";
    cfgDir = mkOpt types.str "/var/lib/zeek" "Directory for Zeek configuration files.";

    user = mkOpt types.str "zeek" "User to run Zeek as.";
    group = mkOpt types.str "zeek" "Group to run Zeek as.";

    enableJsonLogs = mkOption {
      type = types.bool;
      default = true;
      description = "Enable JSON formatted logs for easier parsing.";
    };

    enableFileExtraction = mkOption {
      type = types.bool;
      default = false;
      description = "Enable automatic file extraction from network traffic.";
    };

    localNetworks = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "List of local networks in CIDR notation.";
      example = literalExpression ''["192.168.1.0/24" "10.0.0.0/8"]'';
    };

    extraScripts = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Additional Zeek scripts to load.";
    };

    extraConfig = mkOption {
      type = types.lines;
      default = "";
      description = "Additional Zeek script code to include in local.zeek.";
    };

    redis = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable a dedicated Redis instance (optional).";
      };
      host = mkOpt types.str "127.0.0.1" "Redis server host.";
      port = mkOpt types.port 6379 "Redis server port.";
    };

    elasticsearch = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Whether to enable Elasticsearch output for Filebeat.";
      };
      host = mkOpt types.str "localhost" "Elasticsearch host.";
      port = mkOpt types.port 9200 "Elasticsearch port.";
      index = mkOpt types.str "zeek" "Elasticsearch index prefix.";
    };

    filebeat = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable Filebeat to ship Zeek logs.";
      };
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "Open Zeek-related ports (usually not needed for this direct-run mode).";
    };

    vault = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Whether to enable Vault integration for secrets management.";
      };

      role-id = mkOpt (types.nullOr types.str) null "Absolute path to Vault role-id";
      secret-id = mkOpt (types.nullOr types.str) null "Absolute path to Vault secret-id";
      vault-path = mkOpt types.str "secret/campground/zeek" "Vault KV path for Zeek secrets.";
      kvVersion = mkOpt types.str "v2" "KV Secrets Engine version (v1 or v2).";

      vault-address = mkOption {
        type = types.nullOr types.str;
        default =
          if config.fmf.services.vault-agent.settings ? vault
          then config.fmf.services.vault-agent.settings.vault.address
          else null;
        description = "The address of your Vault";
      };
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.interfaces != [];
        message = "fmf.services.zeek.interfaces must not be empty.";
      }
      {
        assertion = cfg.vault.enable -> (cfg.vault.role-id != null && cfg.vault.secret-id != null);
        message = "fmf.services.zeek.vault.role-id and secret-id must be set when vault is enabled.";
      }
    ];

    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      description = "Zeek network security monitor user";
      home = cfg.cfgDir;
    };
    users.groups.${cfg.group} = {};

    environment.systemPackages = [cfg.package];

    services.redis.servers.zeek = mkIf cfg.redis.enable {
      enable = true;
      port = cfg.redis.port;
      bind = cfg.redis.host;
      save = [
        [900 1]
        [300 10]
        [60 10000]
      ];
      settings = {
        dir = "/var/lib/redis-zeek";
        dbfilename = "dump.rdb";
        appendonly = "yes";
        appendfilename = "appendonly.aof";
      };
    };

    # Base directories and generated configs
    systemd.tmpfiles.rules =
      [
        "d ${cfg.logDir} 0755 ${cfg.user} ${cfg.group} -"
        "d ${cfg.logDir}/current 0755 ${cfg.user} ${cfg.group} -"
        "d ${cfg.spoolDir} 0755 ${cfg.user} ${cfg.group} -"
        "d ${cfg.spoolDir}/extract 0755 ${cfg.user} ${cfg.group} -"
        "d ${cfg.cfgDir} 0755 ${cfg.user} ${cfg.group} -"
        "d ${cfg.cfgDir}/etc 0755 ${cfg.user} ${cfg.group} -"

        "L+ ${cfg.cfgDir}/local.zeek - - - - ${localZeek}"
        "L+ ${cfg.cfgDir}/networks.cfg - - - - ${networksConfig}"
      ]
      ++ (concatMap (iface: [
          "d ${cfg.logDir}/current/${iface} 0755 ${cfg.user} ${cfg.group} -"
          "d ${cfg.spoolDir}/spool-${iface} 0755 ${cfg.user} ${cfg.group} -"
          "d ${cfg.spoolDir}/extract/${iface} 0755 ${cfg.user} ${cfg.group} -"
        ])
        cfg.interfaces)
      ++ optional cfg.redis.enable "d /var/lib/redis-zeek 0750 redis redis -";

    # Target for all instances
    systemd.targets.zeek = {
      description = "Zeek Network Security Monitor (all interfaces)";
      wantedBy = ["multi-user.target"];
      after = ["network-online.target"] ++ optional cfg.redis.enable "redis-zeek.service";
      wants = ["network-online.target"] ++ optional cfg.redis.enable "redis-zeek.service";
    };

    # One service per interface
    systemd.services = listToAttrs (map (iface: {
        name = unitNameForIface iface;
        value = {
          description = "Zeek Network Security Monitor on ${iface}";
          wantedBy = ["zeek.target"];
          after = ["network-online.target"] ++ optional cfg.redis.enable "redis-zeek.service";
          wants = ["network-online.target"] ++ optional cfg.redis.enable "redis-zeek.service";

          path = with pkgs; [cfg.package coreutils];

          serviceConfig = {
            Type = "simple";
            User = cfg.user;
            Group = cfg.group;
            WorkingDirectory = cfg.cfgDir;

            AmbientCapabilities = ["CAP_NET_RAW" "CAP_NET_ADMIN"];
            CapabilityBoundingSet = ["CAP_NET_RAW" "CAP_NET_ADMIN"];

            PrivateTmp = true;
            ProtectSystem = "strict";
            ProtectHome = true;
            ReadWritePaths = [cfg.logDir cfg.spoolDir cfg.cfgDir];

            Restart = "on-failure";
            RestartSec = "5s";
          };

          script = ''
                        set -euo pipefail

                        LOG_DIR="${cfg.logDir}/current/${iface}"
                        SPOOL_DIR="${cfg.spoolDir}/spool-${iface}"
                        EXTRACT_DIR="${cfg.spoolDir}/extract/${iface}"

                        mkdir -p "$LOG_DIR" "$SPOOL_DIR" "$EXTRACT_DIR"

                        # Per-interface overrides (no zeek -l flag at all)
                        cat > "$SPOOL_DIR/site-local.zeek" <<EOF
            redef Log::default_logdir = "$LOG_DIR";
            redef FileExtract::prefix = "$EXTRACT_DIR/";
            EOF

                        exec ${cfg.package}/bin/zeek \
                          -i ${escapeShellArg iface} \
                          -C \
                          "${cfg.cfgDir}/local.zeek" \
                          "$SPOOL_DIR/site-local.zeek"
          '';
        };
      })
      cfg.interfaces);

    # Filebeat (optional)
    services.filebeat = mkIf cfg.filebeat.enable {
      enable = true;
      settings = {
        filebeat.inputs = [
          {
            type = "log";
            enabled = true;
            paths = ["${cfg.logDir}/current/*/*.log"];
            fields = {type = "zeek";};
            json = {
              keys_under_root = true;
              add_error_key = true;
            };
          }
        ];
        output.elasticsearch = mkIf cfg.elasticsearch.enable {
          hosts = ["${cfg.elasticsearch.host}:${toString cfg.elasticsearch.port}"];
          index = "${cfg.elasticsearch.index}-%{+yyyy.MM.dd}";
        };
      };
    };

    networking.firewall.allowedTCPPorts = mkIf cfg.openFirewall [27760 27761];

    # Vault integration (optional)
    fmf.services.vault-agent.services.zeek = mkIf cfg.vault.enable {
      settings = {
        vault.address = cfg.vault.vault-address;
        auto_auth = {
          method = [
            {
              type = "approle";
              config = {
                role_id_file_path = cfg.vault.role-id;
                secret_id_file_path = cfg.vault.secret-id;
                remove_secret_id_file_after_reading = false;
              };
            }
          ];
        };
      };

      secrets = {
        file.files = {
          zeek-secrets = {
            text = ''
              {{ with secret "${cfg.vault.vault-path}" -}}
              {{- if eq "${cfg.vault.kvVersion}" "v1" -}}
              ZEEK_API_KEY={{ .Data.api_key }}
              {{- else -}}
              ZEEK_API_KEY={{ .Data.data.api_key }}
              {{- end -}}
              {{- end -}}
            '';
            permissions = "0400";
            change-action = "restart";
          };
        };
      };
    };
  };
}
