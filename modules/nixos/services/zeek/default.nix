{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.services.zeek;

  # Generate Zeek configuration files (kept for compatibility / debugging; we don't use zeekctl at runtime)
  zeekConfig = pkgs.writeText "zeekctl.cfg" ''
    # NOTE: This file is generated for convenience, but this module does NOT run zeekctl
    # because zeekctl mutates files under its install prefix which is read-only on NixOS.

    ZeekPort = 27760
    LogDir = ${cfg.logDir}
    SpoolDir = ${cfg.spoolDir}
    CfgDir = ${cfg.cfgDir}

    SitePolicyPath = ${cfg.spoolDir}/site
    SitePluginPath = ${cfg.spoolDir}/plugins

    LogRotationInterval = 3600
    LogExpireInterval = 0
    StatsLogEnable = 1
    StatsLogExpireInterval = 0

    CompressCmd = gzip -9
    CompressExtension = gz
  '';

  # Generate node.cfg for standalone or cluster mode (kept, but not used by zeekctl here)
  nodeConfig = pkgs.writeText "node.cfg" (
    if cfg.standalone
    then
      if length cfg.interfaces > 1
      then ''
        [manager]
        type=manager
        host=localhost

        [proxy-1]
        type=proxy
        host=localhost

        ${concatMapStringsSep "\n" (idx: let
          iface = builtins.elemAt cfg.interfaces idx;
        in ''
          [worker-${toString idx}]
          type=worker
          host=localhost
          interface=${iface}
        '') (lib.range 0 (length cfg.interfaces - 1))}
      ''
      else ''
        [zeek]
        type=standalone
        host=localhost
        interface=${builtins.head cfg.interfaces}
      ''
    else ''
      ${cfg.nodeConfigText}
    ''
  );

  # Generate local.zeek with custom scripts
  localZeek = pkgs.writeText "local.zeek" ''
    # Default policy scripts (safe for standalone)
    @load policy/misc/stats

    ${optionalString cfg.enableJsonLogs ''
      # Enable JSON logging
      @load policy/tuning/json-logs.zeek
    ''}

    ${optionalString (cfg.localNetworks != []) ''
      # Define local networks
      redef Site::local_nets = {
        ${concatMapStringsSep ",\n  " (net: "${net}") cfg.localNetworks}
      };
    ''}

    ${optionalString cfg.enableFileExtraction ''
      # Enable file extraction
      @load frameworks/files/extract-all-files
    ''}

    ${concatMapStringsSep "\n" (script: "@load ${script}") cfg.extraScripts}

    ${cfg.extraConfig}
  '';

  # Generate networks.cfg for local network definitions
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

    standalone = mkOption {
      type = types.bool;
      default = true;
      description = "Run Zeek in standalone mode (single node). Set to false for cluster mode.";
    };

    interfaces = mkOption {
      type = types.listOf types.str;
      default = ["eth0"];
      description = "Network interfaces to monitor.";
      example = literalExpression ''["eth0" "eth1"]'';
    };

    logDir = mkOpt types.str "/var/lib/zeek/logs" "Directory for Zeek log files.";
    spoolDir = mkOpt types.str "/var/lib/zeek/spool" "Directory for Zeek spool files.";
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
      example = literalExpression ''
        [
          "policy/protocols/ssl/known-certs"
          "policy/protocols/http/detect-sqli"
          "site/custom-script"
        ]
      '';
    };

    extraConfig = mkOption {
      type = types.lines;
      default = "";
      description = "Additional Zeek script code to include in local.zeek.";
      example = literalExpression ''
        redef HTTP::default_capture_password = T;
        redef FTP::default_capture_password = T;
      '';
    };

    nodeConfigText = mkOption {
      type = types.lines;
      default = "";
      description = "Custom node.cfg content for cluster mode. Only used when standalone = false.";
    };

    redis = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Whether to enable Redis for Zeek data storage (requires broker framework).";
      };

      host = mkOpt types.str "127.0.0.1" "Redis server host.";
      port = mkOpt types.port 6379 "Redis server port.";
    };

    elasticsearch = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Whether to enable Elasticsearch output for Zeek logs.";
      };

      host = mkOpt types.str "localhost" "Elasticsearch host.";
      port = mkOpt types.port 9200 "Elasticsearch port.";
      index = mkOpt types.str "zeek" "Elasticsearch index prefix.";
    };

    filebeat = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Whether to enable Filebeat for shipping Zeek logs.";
      };
    };

    plugins = mkOption {
      type = types.listOf types.package;
      default = [];
      description = "List of Zeek plugin packages to install.";
      example = literalExpression ''[ pkgs.zeek-plugins.af_packet ]'';
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to open firewall ports for Zeek cluster communication (27760-27761).";
    };

    vault = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Whether to enable Vault integration for secrets management.";
      };

      role-id =
        mkOpt (types.nullOr types.str) null
        "Absolute path to the Vault role-id";
      secret-id =
        mkOpt (types.nullOr types.str) null
        "Absolute path to the Vault secret-id";
      vault-path =
        mkOpt types.str "secret/campground/zeek"
        "The Vault path to the KV containing Zeek secrets.";
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
        assertion = !cfg.standalone -> cfg.nodeConfigText != "";
        message = "fmf.services.zeek.nodeConfigText must be set when standalone = false.";
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

    environment.systemPackages = [
      (
        if cfg.plugins != []
        then cfg.package.override {plugins = cfg.plugins;}
        else cfg.package
      )
    ];

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

    # Directories + generated config files
    systemd.tmpfiles.rules =
      [
        "d ${cfg.logDir} 0755 ${cfg.user} ${cfg.group} -"
        "d ${cfg.logDir}/current 0755 ${cfg.user} ${cfg.group} -"
        "d ${cfg.spoolDir} 0755 ${cfg.user} ${cfg.group} -"
        "d ${cfg.spoolDir}/extract 0755 ${cfg.user} ${cfg.group} -"
        "d ${cfg.spoolDir}/site 0755 ${cfg.user} ${cfg.group} -"
        "d ${cfg.spoolDir}/plugins 0755 ${cfg.user} ${cfg.group} -"
        "d ${cfg.cfgDir} 0755 ${cfg.user} ${cfg.group} -"
        "d ${cfg.cfgDir}/etc 0755 ${cfg.user} ${cfg.group} -"

        # Generated config files (useful for debugging / compatibility)
        "L+ ${cfg.cfgDir}/zeekctl.cfg - - - - ${zeekConfig}"
        "L+ ${cfg.cfgDir}/node.cfg - - - - ${nodeConfig}"
        "L+ ${cfg.cfgDir}/local.zeek - - - - ${localZeek}"
        "L+ ${cfg.cfgDir}/networks.cfg - - - - ${networksConfig}"

        "L+ ${cfg.cfgDir}/etc/zeekctl.cfg - - - - ${zeekConfig}"
        "L+ ${cfg.cfgDir}/etc/node.cfg - - - - ${nodeConfig}"
        "L+ ${cfg.cfgDir}/etc/networks.cfg - - - - ${networksConfig}"
      ]
      ++ (concatMap (iface: [
          "d ${cfg.logDir}/current/${iface} 0755 ${cfg.user} ${cfg.group} -"
          "d ${cfg.spoolDir}/spool-${iface} 0755 ${cfg.user} ${cfg.group} -"
          "d ${cfg.spoolDir}/extract/${iface} 0755 ${cfg.user} ${cfg.group} -"
        ])
        cfg.interfaces)
      ++ optional cfg.redis.enable "d /var/lib/redis-zeek 0750 redis redis -";

    # A target that means "all zeek instances"
    systemd.targets.zeek = {
      description = "Zeek Network Security Monitor (all interfaces)";
      wantedBy = ["multi-user.target"];
      after = ["network-online.target"] ++ optional cfg.redis.enable "redis-zeek.service";
      wants = ["network-online.target"] ++ optional cfg.redis.enable "redis-zeek.service";
    };

    # One service per interface: zeek@eth0, zeek@eth1, ...
    systemd.services = listToAttrs (map (iface: {
        name = unitNameForIface iface;
        value = {
          description = "Zeek Network Security Monitor on ${iface}";
          wantedBy = ["zeek.target"];
          after = ["network-online.target"] ++ optional cfg.redis.enable "redis-zeek.service";
          wants = ["network-online.target"] ++ optional cfg.redis.enable "redis-zeek.service";

          path = with pkgs; [cfg.package iproute2 coreutils];

          serviceConfig = {
            Type = "simple";
            User = cfg.user;
            Group = cfg.group;
            WorkingDirectory = cfg.cfgDir;

            # packet capture without running as root
            AmbientCapabilities = ["CAP_NET_RAW" "CAP_NET_ADMIN"];
            CapabilityBoundingSet = ["CAP_NET_RAW" "CAP_NET_ADMIN"];

            # hardening
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

            # Per-interface overrides (log dir + file extraction prefix)
            cat > "$SPOOL_DIR/site-local.zeek" <<'EOF'
            redef Log::default_logdir = "'"$LOG_DIR"'";
            redef FileExtract::prefix = "'"$EXTRACT_DIR"'/";
            EOF

            exec ${cfg.package}/bin/zeek \
              -i ${escapeShellArg iface} \
              -C \
              -l "$LOG_DIR" \
              "${cfg.cfgDir}/local.zeek" \
              "$SPOOL_DIR/site-local.zeek"
          '';
        };
      })
      cfg.interfaces);

    # Log rotation (kept)
    services.logrotate.settings.zeek = {
      files = "${cfg.logDir}/*.log";
      frequency = "daily";
      rotate = 7;
      compress = true;
      delaycompress = true;
      missingok = true;
      notifempty = true;
      su = "${cfg.user} ${cfg.group}";
    };

    # Filebeat (kept)
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

    # Vault integration (kept)
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
