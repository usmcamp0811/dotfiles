{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.services.zeek;

  # Generate Zeek configuration files
  zeekConfig = pkgs.writeText "zeekctl.cfg" ''
    LogDir = ${cfg.logDir}
    SpoolDir = ${cfg.spoolDir}
    CfgDir = ${cfg.cfgDir}
  '';

  # Generate node.cfg for standalone or cluster mode
  nodeConfig = pkgs.writeText "node.cfg" (
    if cfg.standalone
    then ''
      [zeek]
      type=standalone
      host=localhost
      interface=${concatStringsSep "," cfg.interfaces}
    ''
    else ''
      ${cfg.nodeConfigText}
    ''
  );

  # Generate local.zeek with custom scripts
  localZeek = pkgs.writeText "local.zeek" ''
    # Enable default scripts
    @load base/frameworks/cluster
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
    then concatMapStringsSep "\n" (net: let
      # Extract network and create a label from it
      parts = lib.splitString "/" net;
      addr = builtins.head parts;
    in "${net}       Network_${builtins.replaceStrings ["."] ["_"] addr}") cfg.localNetworks
    else "# No local networks defined\n"
  );
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
      example = literalExpression ''
        [manager]
        type=manager
        host=192.168.1.10

        [proxy-1]
        type=proxy
        host=192.168.1.10

        [worker-1]
        type=worker
        host=192.168.1.11
        interface=eth0
      '';
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
      description = "Whether to open firewall ports for Zeek cluster communication (47760-47761).";
    };

    vault = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Whether to enable Vault integration for secrets management.";
      };

      role-id = mkOpt (types.nullOr types.str) null
        "Absolute path to the Vault role-id";
      secret-id = mkOpt (types.nullOr types.str) null
        "Absolute path to the Vault secret-id";
      vault-path = mkOpt types.str "secret/campground/zeek"
        "The Vault path to the KV containing Zeek secrets.";
      kvVersion = mkOpt types.str "v2" "KV Secrets Engine version (v1 or v2).";
      vault-address = mkOption {
        type = types.nullOr types.str;
        default = if config.fmf.services.vault-agent.settings ? vault then
          config.fmf.services.vault-agent.settings.vault.address
        else
          null;
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

    # Create zeek user and group
    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      description = "Zeek network security monitor user";
      home = cfg.cfgDir;
    };

    users.groups.${cfg.group} = {};

    # Install Zeek package with plugins
    environment.systemPackages = [
      (if cfg.plugins != []
        then cfg.package.override {plugins = cfg.plugins;}
        else cfg.package)
    ];

    # Redis (separate instance) if requested
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

    # Create necessary directories
    systemd.tmpfiles.rules = [
      "d ${cfg.logDir} 0755 ${cfg.user} ${cfg.group} -"
      "d ${cfg.spoolDir} 0755 ${cfg.user} ${cfg.group} -"
      "d ${cfg.cfgDir} 0755 ${cfg.user} ${cfg.group} -"
      "d ${cfg.cfgDir}/etc 0755 ${cfg.user} ${cfg.group} -"
      "L+ ${cfg.cfgDir}/zeekctl.cfg - - - - ${zeekConfig}"
      "L+ ${cfg.cfgDir}/node.cfg - - - - ${nodeConfig}"
      "L+ ${cfg.cfgDir}/local.zeek - - - - ${localZeek}"
      "L+ ${cfg.cfgDir}/networks.cfg - - - - ${networksConfig}"
      "L+ ${cfg.cfgDir}/etc/zeekctl.cfg - - - - ${zeekConfig}"
      "L+ ${cfg.cfgDir}/etc/node.cfg - - - - ${nodeConfig}"
      "L+ ${cfg.cfgDir}/etc/networks.cfg - - - - ${networksConfig}"
    ] ++ optional cfg.redis.enable "d /var/lib/redis-zeek 0750 redis redis -";

    # Main Zeek service
    systemd.services.zeek = {
      description = "Zeek Network Security Monitor";
      after = ["network-online.target"] ++ optional cfg.redis.enable "redis-zeek.service";
      wants = ["network-online.target"];
      wantedBy = ["multi-user.target"];

      serviceConfig = {
        Type = "forking";
        User = cfg.user;
        Group = cfg.group;
        ExecStart = "${cfg.package}/bin/zeekctl start";
        ExecStop = "${cfg.package}/bin/zeekctl stop";
        ExecReload = "${cfg.package}/bin/zeekctl restart";
        Restart = "on-failure";
        RestartSec = "10s";

        # Security hardening
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [cfg.logDir cfg.spoolDir cfg.cfgDir];

        # Network capabilities for packet capture
        AmbientCapabilities = ["CAP_NET_RAW" "CAP_NET_ADMIN"];
        CapabilityBoundingSet = ["CAP_NET_RAW" "CAP_NET_ADMIN"];
      };

      preStart = ''
        # Deploy Zeek configuration
        cd ${cfg.cfgDir}
        ${cfg.package}/bin/zeekctl deploy
      '';
    };

    # Log rotation service
    systemd.services.zeek-logrotate = {
      description = "Zeek log rotation";
      serviceConfig = {
        Type = "oneshot";
        User = cfg.user;
        Group = cfg.group;
        ExecStart = "${cfg.package}/bin/zeekctl cron";
      };
    };

    systemd.timers.zeek-logrotate = {
      description = "Zeek log rotation timer";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = "hourly";
        Persistent = true;
      };
    };

    # Filebeat configuration for log shipping
    services.filebeat = mkIf cfg.filebeat.enable {
      enable = true;
      settings = {
        filebeat.inputs = [
          {
            type = "log";
            enabled = true;
            paths = ["${cfg.logDir}/current/*.log"];
            fields = {
              type = "zeek";
            };
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

    # Open firewall ports for cluster communication
    networking.firewall.allowedTCPPorts = mkIf cfg.openFirewall [47760 47761];

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
              # Zeek secrets from Vault
              ZEEK_API_KEY={{ .Data.api_key }}
              {{- else -}}
              # Zeek secrets from Vault
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
