{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.campground; let
  cfg = config.campground.services.crystal-forge;

  host = config.networking.hostName;
in {
  options.campground.services.crystal-forge = {
    enable = mkEnableOption "Enable the Crystal Forge service(s)";
    log_level = lib.mkOption {
      type = lib.types.enum ["off" "error" "warn" "info" "debug" "trace"];
      default = "debug";
    };
    configPath = mkOption {
      type = types.path;
      default = "/var/lib/crystal-forge/config.toml";
      description = "Path to the final config.toml file.";
    };
    database = {
      host = mkOption {
        type = types.str;
        default = "localhost";
      };
      user = mkOption {
        type = types.str;
        default = "crystal_forge";
      };
      password = mkOption {
        type = types.str;
        default = "password";
      };
      passwordFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Optional path to a file containing the database password. Overrides 'password'.";
      };
      name = mkOption {
        type = types.str;
        default = "crystal_forge";
      };
    };
    server = {
      enable = mkEnableOption "Enable the Crystal Forge Server";
      host = mkOption {
        type = types.str;
        default = "0.0.0.0";
      };
      port = mkOption {
        type = types.port;
        default = 3000;
      };
    };
    client = {
      enable = mkEnableOption "Enable the Crystal Forge Agent";
      server_host = mkOption {
        type = types.str;
        default = "reckless";
      };
      server_port = mkOption {
        type = types.port;
        default = 3000;
      };
    };
    flakes = {
      watched = lib.mkOption {
        type = lib.types.listOf (lib.types.submodule {
          options = {
            name = lib.mkOption {
              type = lib.types.str;
              description = "Name identifier for the flake";
            };
            repo_url = lib.mkOption {
              type = lib.types.str;
              description = "Repository URL of the flake";
            };
            auto_poll = lib.mkOption {
              type = lib.types.bool;
              default = false; # Add default value
              description = "Whether to automatically poll the repository for new commits instead of relying solely on webhooks";
            };
          };
        });
        default = [];
        description = "List of flakes to watch for changes";
        example = [
          {
            name = "dotfiles";
            repo_url = "git+https://gitlab.com/usmcamp0811/dotfiles";
            auto_poll = false;
          }
        ];
      };
      flake_polling_interval = lib.mkOption {
        type = lib.types.str;
        default = "10m"; # 10 minutes
        description = "Interval between flake polling checks (e.g., '10m', '1h')";
      };

      commit_evaluation_interval = lib.mkOption {
        type = lib.types.str;
        default = "1m"; # 1 minute
        description = "Interval between commit evaluation checks (e.g., '1m', '5m')";
      };

      build_processing_interval = lib.mkOption {
        type = lib.types.str;
        default = "1m"; # 1 minute
        description = "Interval between build processing checks (e.g., '1m', '5m')";
      };
    };
    build = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = cfg.server.enable;
        description = "Crystal Forge Builder";
      };
      cores = lib.mkOption {
        type = lib.types.ints.positive;
        default = 8;
        description = "Maximum CPU cores to use per build job";
      };

      max_jobs = lib.mkOption {
        type = lib.types.ints.positive;
        default = 1;
        description = "Maximum number of concurrent build jobs";
      };

      use_substitutes = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to use binary substitutes/caches";
      };

      offline = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Build in offline mode (no network access)";
      };

      poll_interval = lib.mkOption {
        type = lib.types.str;
        default = "5m";
        description = "Interval between checking for new build jobs";
      };
    };

    # Vulnix configuration options
    vulnix = {
      timeout = lib.mkOption {
        type = lib.types.str;
        default = "5m";
        description = "Timeout for vulnix scans";
      };

      max_retries = lib.mkOption {
        type = lib.types.ints.unsigned;
        default = 5;
        description = "Maximum number of retry attempts for failed scans";
      };

      enable_whitelist = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable CVE whitelist filtering";
      };

      extra_args = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Additional arguments to pass to vulnix";
      };

      whitelist_path = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Path to CVE whitelist file";
      };

      poll_interval = lib.mkOption {
        type = lib.types.str;
        default = "1m";
        description = "Interval between checking for new CVE scan jobs";
      };
    };

    # Cache configuration options
    cache = {
      push_to = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Cache URI to push to (e.g., 's3://bucket', 'https://cache.example.com')";
      };

      push_after_build = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Automatically push builds to cache after successful completion";
      };

      signing_key = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Path to private signing key for cache signatures";
      };

      compression = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Compression method for cache uploads";
      };

      push_filter = lib.mkOption {
        type = lib.types.nullOr (lib.types.listOf lib.types.str);
        default = null;
        description = "Only push builds for these systems/targets";
      };

      parallel_uploads = lib.mkOption {
        type = lib.types.ints.positive;
        default = 4;
        description = "Maximum parallel uploads to cache";
      };
    };
    systems = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule {
        options = {
          hostname = lib.mkOption {
            type = lib.types.str;
            description = "System hostname";
          };
          public_key = lib.mkOption {
            type = lib.types.str;
            description = "Base64-encoded Ed25519 public key";
          };
          environment = lib.mkOption {
            type = lib.types.str;
            description = "Environment name (e.g., dev, prod, staging)";
          };
          flake_name = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Reference to a flake name from flakes.watched";
          };
        };
      });
      default = [];
      description = "Systems to register with Crystal Forge";
      example = [
        {
          hostname = "myhost";
          public_key = "base64encodedkey";
          environment = "production";
          flake_name = "dotfiles";
        }
      ];
    };

    environments = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule {
        options = {
          name = lib.mkOption {
            type = lib.types.str;
            description = "Environment name (e.g., dev, prod, staging)";
          };
          description = lib.mkOption {
            type = lib.types.str;
            description = "Description of the environment";
          };
          is_active = lib.mkOption {
            type = lib.types.bool;
            description = "Whether the environment is currently active";
          };
          risk_profile = lib.mkOption {
            type = lib.types.str;
            description = "Risk profile for this environment";
          };
          compliance_level = lib.mkOption {
            type = lib.types.str;
            description = "Compliance level for this environment";
          };
        };
      });
      default = [];
      description = "List of environments for agents and evaluation";
      example = [
        {
          name = "dev";
          description = "Development environment for Crystal Forge agents and evaluation";
          is_active = true;
          risk_profile = "LOW";
          compliance_level = "NONE";
        }
      ];
    };
    role-id =
      mkOpt types.str
      config.campground.services.vault-agent.settings.vault.role-id
      "Absolute path to the Vault role-id";
    secret-id =
      mkOpt types.str
      config.campground.services.vault-agent.settings.vault.secret-id
      "Absolute path to the Vault secret-id";
    vault-path =
      mkOpt types.str "secret/campground/crystal-forge"
      "The Vault path to the KV containing the KVs that are for each database";
    kvVersion = mkOption {
      type = types.enum ["v1" "v2"];
      default = "v2";
      description = "KV store version";
    };
    vault-address = mkOption {
      type = types.str;
      default = config.campground.services.vault-agent.settings.vault.address;
      description = "The address of your Vault";
    };
  };

  config = mkIf cfg.enable {
    # Configure the base Crystal Forge service with our options
    services.crystal-forge = {
      enable = true;
      inherit (cfg) log_level database;

      # Pass through server configuration
      server = mkIf cfg.server.enable {
        enable = true;
        inherit (cfg.server) host port;
      };

      # Pass through client configuration, but we'll handle the private key separately
      client = mkIf cfg.client.enable {
        enable = true;
        inherit (cfg.client) server_port server_host;
        private_key = "/var/lib/crystal-forge/agent.key";
      };

      # Pass through all other configuration sections
      inherit (cfg) flakes systems environments build vulnix cache;
    };

    # Pre-start script to copy the agent key from vault
    systemd.services.crystal-forge-agent = mkIf cfg.client.enable {
      preStart = mkForce ''
        mkdir -p /var/lib/crystal-forge/
        cp /tmp/detsys-vault/agent.key /var/lib/crystal-forge/agent.key
      '';
    };
    systemd.services.crystal-forge-server.serviceConfig = {
      MemoryMax = lib.mkForce "95%"; # Leave 5% for OS
      MemoryHigh = lib.mkForce "85%"; # Start throttling early
      MemorySwapMax = lib.mkForce "10G"; # Minimal swap usage
    };
    systemd.services.crystal-forge-server.environment = {
      GC_INITIAL_HEAP_SIZE = "128M";
      GC_MAX_HEAP_SIZE = "12G";
    };
    systemd.services.crystal-forge-builder.environment = {
      GC_INITIAL_HEAP_SIZE = "128M";
      GC_MAX_HEAP_SIZE = "12G";
    };
    systemd.services.crystal-forge-builder.serviceConfig = {
      # Memory Management
      MemoryMax = lib.mkForce "90%"; # Hard limit - leave 10% for OS
      MemoryHigh = lib.mkForce "80%"; # Soft limit - start pressure early
      MemorySwapMax = lib.mkForce "5G"; # Limited swap to prevent thrashing

      # CPU Priority and Control
      CPUWeight = lib.mkForce "1000"; # High CPU priority (default is 100)
      Nice = lib.mkForce "-10"; # Higher process priority
      CPUQuota = lib.mkForce "800%"; # Allow up to 8 cores if available

      # I/O Priority
      IOWeight = lib.mkForce "1000"; # High I/O priority
      IOSchedulingClass = lib.mkForce "1"; # Real-time I/O class
      IOSchedulingPriority = lib.mkForce "4"; # High RT priority (0-7, lower = higher)

      # Process Protection
      OOMScoreAdjust = lib.mkForce "-500"; # Protect from OOM killer

      # Restart Behavior
      Restart = lib.mkForce "always";
      RestartSec = lib.mkForce "5";
      StartLimitBurst = lib.mkForce "10";
      StartLimitIntervalSec = lib.mkForce "60";

      # Process Limits
      LimitNOFILE = lib.mkForce "1048576"; # High file descriptor limit
      LimitNPROC = lib.mkForce "32768"; # High process limit

      # Optional: Pin to specific cores if you have many
      # CPUAffinity = lib.mkForce "0-7"; # Use first 8 cores
    };

    # systemd.services.crystal-forge-server.preStart = ''
    #   mkdir -p /var/lib/crystal-forge/
    #   chown -R crystal-forge:crystal-forge /var/lib/crystal-forge/
    #   ${pkgs.postgresql_16}/bin/psql -U postgres -d crystal_forge <<SQL
    #   GRANT CONNECT ON DATABASE crystal_forge TO grafana;
    #   GRANT USAGE ON SCHEMA public TO grafana;
    #   GRANT SELECT ON ALL TABLES IN SCHEMA public TO grafana;
    #   GRANT SELECT ON ALL SEQUENCES IN SCHEMA public TO grafana;
    #   ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO grafana;
    #   ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON SEQUENCES TO grafana;
    #   SQL
    # -- Complete Grafana PostgreSQL Permissions Setup
    # -- 1. Grant database connection privileges
    # GRANT CONNECT ON DATABASE crystal_forge TO grafana;
    #
    # -- 2. Grant schema usage
    # GRANT USAGE ON SCHEMA public TO grafana;
    #
    # -- 3. Grant read access on ALL existing tables, views, and sequences
    # GRANT SELECT ON ALL TABLES IN SCHEMA public TO grafana;
    # GRANT SELECT ON ALL SEQUENCES IN SCHEMA public TO grafana;
    #
    # -- 4. Grant read access to future tables, views, and sequences
    # ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO grafana;
    # ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON SEQUENCES TO grafana;
    #
    # -- 5. Explicit grant on systems table (covers edge cases)
    # GRANT SELECT ON systems TO grafana;
    # GRANT SELECT ON public.systems TO grafana;
    # '';

    systemd.tmpfiles.rules = [
      "d /var/lib/crystal-forge 0700 crystal-forge crystal-forge -"
    ];

    # Vault agent configuration for fetching the private key
    campground.services = {
      vault-agent = {
        services = {
          "crystal-forge-agent" = {
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
                  "agent.key" = {
                    text = ''{{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.${host} }}{{ else }}{{ .Data.data.${host} }}{{ end }}{{ end }}'';
                    permissions = "0600";
                    change-action = "restart";
                  };
                };
              };
            };
          };
        };
      };
    };
  };
}
