{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.services.garage;

  garageEnvironmentFile = "/run/keys/environment/garage/garage.EnvFile";

  garageSettings =
    {
      metadata_dir = cfg.metadataDir;
      data_dir = cfg.dataDir;

      db_engine = cfg.dbEngine;
      replication_factor = cfg.replicationFactor;

      rpc_bind_addr = cfg.rpcBindAddress;

      s3_api =
        {
          api_bind_addr = cfg.s3ApiBindAddress;
          s3_region = cfg.region;
        }
        // optionalAttrs (cfg.s3RootDomain != null) {
          root_domain = cfg.s3RootDomain;
        };
    }
    // optionalAttrs (cfg.rpcPublicAddress != null) {
      rpc_public_addr = cfg.rpcPublicAddress;
    }
    // optionalAttrs (cfg.bootstrapPeers != []) {
      bootstrap_peers = cfg.bootstrapPeers;
    }
    // optionalAttrs cfg.web.enable {
      s3_web = {
        bind_addr = cfg.web.bindAddress;
        root_domain = cfg.web.rootDomain;
        index = cfg.web.index;
      };
    }
    // optionalAttrs cfg.admin.enable {
      admin = {
        api_bind_addr = cfg.admin.bindAddress;
        metrics_require_token = cfg.admin.metricsRequireToken;
      };
    }
    // cfg.settings;
in {
  options.fmf.services.garage = with types; {
    enable = mkBoolOpt false "Enable Garage S3-compatible object storage.";

    package =
      mkOpt package pkgs.garage_2
      "Garage package to use.";

    metadataDir =
      mkOpt str "/var/lib/garage/meta"
      "Directory used to store Garage metadata.";

    dataDir =
      mkOpt (either str (listOf attrs)) "/var/lib/garage/data"
      "Directory or directories used to store Garage object data.";

    dbEngine =
      mkOpt str "lmdb"
      "Garage metadata database engine.";

    replicationFactor =
      mkOpt ints.positive 1
      "Number of copies Garage stores for each object.";

    region =
      mkOpt str "garage"
      "S3 region exposed by Garage.";

    rpcBindAddress =
      mkOpt str "0.0.0.0:3901"
      "Address used by Garage for cluster RPC traffic.";

    rpcPublicAddress =
      mkOpt (nullOr str) null
      "RPC address advertised to other Garage nodes.";

    bootstrapPeers =
      mkOpt (listOf str) []
      "Garage cluster peers used to bootstrap this node.";

    s3ApiBindAddress =
      mkOpt str "0.0.0.0:3900"
      "Address used by the Garage S3 API.";

    s3RootDomain =
      mkOpt (nullOr str) null
      "Optional root domain used for virtual-hosted S3 buckets.";

    openFirewall =
      mkBoolOpt true
      "Open the S3 API port in the firewall.";

    openRpcFirewall =
      mkBoolOpt false
      "Open the Garage cluster RPC port in the firewall.";

    logLevel =
      mkOpt
      (enum [
        "error"
        "warn"
        "info"
        "debug"
        "trace"
      ])
      "info"
      "Garage log level.";

    settings =
      mkOpt attrs {}
      "Additional Garage settings merged into the generated configuration.";

    web = {
      enable =
        mkBoolOpt false
        "Enable Garage's S3 static website endpoint.";

      bindAddress =
        mkOpt str "0.0.0.0:3902"
        "Address used by the Garage S3 website endpoint.";

      rootDomain =
        mkOpt str ".web.garage"
        "Root domain used by the Garage S3 website endpoint.";

      index =
        mkOpt str "index.html"
        "Default index document for Garage S3 websites.";

      openFirewall =
        mkBoolOpt false
        "Open the S3 website endpoint in the firewall.";
    };

    admin = {
      enable =
        mkBoolOpt true
        "Enable the Garage administration and metrics endpoint.";

      bindAddress =
        mkOpt str "127.0.0.1:3903"
        "Address used by the Garage administration API.";

      metricsRequireToken =
        mkBoolOpt true
        "Require authentication for Garage metrics.";

      openFirewall =
        mkBoolOpt false
        "Open the Garage administration endpoint in the firewall.";
    };

    role-id =
      mkOpt str
      config.fmf.services.vault-agent.settings.vault.role-id
      "Absolute path to the Vault role-id.";

    secret-id =
      mkOpt str
      config.fmf.services.vault-agent.settings.vault.secret-id
      "Absolute path to the Vault secret-id.";

    vault-path =
      mkOpt str "secret/campground/garage"
      "Vault KV path containing Garage secrets.";

    kvVersion = mkOption {
      type = enum [
        "v1"
        "v2"
      ];
      default = "v2";
      description = "Vault KV store version.";
    };

    vault-address = mkOption {
      type = str;
      default = config.fmf.services.vault-agent.settings.vault.address;
      description = "Vault server address.";
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion =
          !(hasAttr "rpc_secret" cfg.settings);
        message = ''
          fmf.services.garage.settings must not contain rpc_secret.
          Store Garage secrets in Vault instead.
        '';
      }
      {
        assertion =
          !cfg.web.enable || cfg.web.rootDomain != "";
        message = ''
          fmf.services.garage.web.rootDomain must be set when the S3
          website endpoint is enabled.
        '';
      }
    ];

    services.garage = {
      enable = true;
      package = cfg.package;
      logLevel = cfg.logLevel;

      settings = garageSettings;

      # Secrets are rendered at runtime by the FMF Vault Agent module.
      environmentFile = garageEnvironmentFile;
    };

    networking.firewall.allowedTCPPorts =
      optionals cfg.openFirewall [
        3900
      ]
      ++ optionals cfg.openRpcFirewall [
        3901
      ]
      ++ optionals (cfg.web.enable && cfg.web.openFirewall) [
        3902
      ]
      ++ optionals (cfg.admin.enable && cfg.admin.openFirewall) [
        3903
      ];

    fmf.services.vault-agent.services.garage = {
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

      secrets.environment = {
        change-action = "restart";

        templates.garage = {
          text = ''
            {{ with secret "${cfg.vault-path}" }}
            GARAGE_RPC_SECRET='{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.rpc_secret }}{{ else }}{{ .Data.data.rpc_secret }}{{ end }}'
            ${optionalString cfg.admin.enable ''
              GARAGE_ADMIN_TOKEN='{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.admin_token }}{{ else }}{{ .Data.data.admin_token }}{{ end }}'
            ''}${optionalString (cfg.admin.enable && cfg.admin.metricsRequireToken) ''
              GARAGE_METRICS_TOKEN='{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.metrics_token }}{{ else }}{{ .Data.data.metrics_token }}{{ end }}'
            ''}{{ end }}
          '';
        };
      };
    };
  };
}
