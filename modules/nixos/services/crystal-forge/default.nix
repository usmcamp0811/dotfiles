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
      port = mkOption {
        type = types.port;
        default = 5432;
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
    auth = {
      ssh_key_path = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Path to SSH private key for Git authentication. If null, SSH keys will be generated automatically.";
      };
      ssh_known_hosts_path = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = "/var/lib/crystal-forge/.ssh/known_hosts";
        description = "Path to SSH known_hosts file. If null, defaults to /var/lib/crystal-forge/.ssh/known_hosts";
      };
      netrc_path = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = "/var/lib/crystal-forge/.netrc";
        description = "Path to .netrc file for HTTPS Git authentication. If null, defaults to /var/lib/crystal-forge/.netrc";
      };
      ssh_disable_strict_host_checking = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether to disable strict host key checking for SSH";
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
      private_key = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to Ed25519 private key for agent authentication";
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
              default = false;
              description = "Whether to automatically poll the repository for new commits instead of relying solely on webhooks";
            };
            initial_commit_depth = lib.mkOption {
              type = lib.types.ints.positive;
              default = 10;
              description = "Number of commits to fetch initially when adding the flake";
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
            initial_commit_depth = 10;
          }
        ];
      };
      flake_polling_interval = lib.mkOption {
        type = lib.types.str;
        default = "10m";
        description = "Interval between flake polling checks (e.g., '10m', '1h')";
      };
      commit_evaluation_interval = lib.mkOption {
        type = lib.types.str;
        default = "1m";
        description = "Interval between commit evaluation checks (e.g., '1m', '5m')";
      };
      build_processing_interval = lib.mkOption {
        type = lib.types.str;
        default = "1m";
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
        default = 1;
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
      max_silent_time = lib.mkOption {
        type = lib.types.str;
        default = "1h";
        description = "Maximum time a build can be silent before timing out";
      };
      timeout = lib.mkOption {
        type = lib.types.str;
        default = "2h";
        description = "Maximum total time for a build before timing out";
      };
      sandbox = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable sandbox for builds";
      };
      use_systemd_scope = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to use systemd-run for resource isolation";
      };
      systemd_memory_max = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = "64G";
        description = "Memory limit for systemd scope (e.g., '4G', '2048M')";
      };
      systemd_cpu_quota = lib.mkOption {
        type = lib.types.nullOr lib.types.ints.positive;
        default = 1000;
        description = "CPU quota as percentage (e.g., 300 for 3 cores worth)";
      };
      systemd_timeout_stop_sec = lib.mkOption {
        type = lib.types.nullOr lib.types.ints.positive;
        default = 600;
        description = "Timeout for systemd scope stop operation in seconds";
      };
      systemd_properties = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "MemorySwapMax=8G"
          "TasksMax=3000"
        ];
        description = "Additional systemd properties to set";
        example = [
          "MemorySwapMax=2G"
          "TasksMax=3000"
          "IOWeight=100"
        ];
      };
    };
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
    cache = {
      cache_type = lib.mkOption {
        type = lib.types.enum ["S3" "Attic" "Http" "Nix"];
        default = "Nix";
        description = "Type of cache to use";
      };
      push_to = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Cache URI to push to";
      };
      push_after_build = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Push after build";
      };
      signing_key = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Signing key path";
      };
      compression = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Compression method";
      };
      push_filter = lib.mkOption {
        type = lib.types.nullOr (lib.types.listOf lib.types.str);
        default = null;
        description = "Push filter";
      };
      parallel_uploads = lib.mkOption {
        type = lib.types.ints.positive;
        default = 4;
        description = "Parallel uploads";
      };
      # S3-specific options
      s3_region = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "S3 region for cache";
      };
      s3_profile = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "AWS profile to use for S3 cache";
      };
      # Attic-specific options
      attic_token = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Attic authentication token";
      };
      attic_cache_name = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Attic cache name";
      };
      # Retry configuration
      max_retries = lib.mkOption {
        type = lib.types.ints.unsigned;
        default = 3;
        description = "Maximum retry attempts for cache operations";
      };
      retry_delay_seconds = lib.mkOption {
        type = lib.types.ints.unsigned;
        default = 5;
        description = "Delay between retry attempts in seconds";
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
    # Database initialization
    local-database = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to set up and manage a local PostgreSQL database";
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
      inherit (cfg) log_level database local-database;

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
      inherit (cfg) flakes systems environments vulnix cache auth;

      build =
        cfg.build
        // {
          systemd_properties =
            (cfg.build.systemd_properties or [])
            ++ (lib.optionals (cfg.cache.cache_type == "Attic") [
              "EnvironmentFile=-/var/lib/crystal-forge/attic-env"
              "Environment=HOME=/var/lib/crystal-forge"
              "Environment=XDG_CONFIG_HOME=/var/lib/crystal-forge/.config"
              "Environment=NIX_LOG=trace"
              "Environment=NIX_SHOW_STATS=1"
            ]);
        };
    };

    systemd.services.crystal-forge-setup = {
      description = "Crystal Forge Setup - Copy Vault Agent Files";
      wantedBy = ["multi-user.target"];
      after =
        lib.optional cfg.client.enable "vault-agent-crystal-forge-agent.service"
        ++ lib.optional cfg.build.enable "vault-agent-crystal-forge-builder.service";
      wants =
        lib.optional cfg.client.enable "vault-agent-crystal-forge-agent.service"
        ++ lib.optional cfg.build.enable "vault-agent-crystal-forge-builder.service";

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = "root";
        Group = "root";
      };

      script = ''
                set -euo pipefail
                echo "Starting Crystal Forge setup..."
                # Create directory
                mkdir -p /var/lib/crystal-forge/

                ${lib.optionalString cfg.client.enable ''
          # Wait for and copy agent key
          echo "Waiting for vault-agent to create agent.key..."
          timeout=300  # 5 minutes
          elapsed=0
          while [ ! -f /tmp/detsys-vault/agent.key ] && [ $elapsed -lt $timeout ]; do
            sleep 2
            elapsed=$((elapsed + 2))
          done
          if [ ! -f /tmp/detsys-vault/agent.key ]; then
            echo "ERROR: agent.key not found after $timeout seconds"
            exit 1
          fi
          cp /tmp/detsys-vault/agent.key /var/lib/crystal-forge/agent.key
          chmod 600 /var/lib/crystal-forge/agent.key
          echo "✅ Agent key copied successfully"
        ''}

        ${lib.optionalString (cfg.build.enable && cfg.cache.cache_type == "Attic") ''
          # Wait for and copy attic environment file
          echo "Waiting for vault-agent to create attic-env..."
          elapsed=0
          while [ ! -f /tmp/detsys-vault/attic-env ] && [ $elapsed -lt $timeout ]; do
            sleep 2
            elapsed=$((elapsed + 2))
          done
          if [ ! -f /tmp/detsys-vault/attic-env ]; then
            echo "ERROR: attic-env not found after $timeout seconds"
            exit 1
          fi
          cp /tmp/detsys-vault/attic-env /var/lib/crystal-forge/attic-env
          chmod 644 /var/lib/crystal-forge/attic-env
          echo "✅ Attic environment file copied successfully"
        ''}

        echo "Crystal Forge setup completed successfully"
      '';
    };

    # Update service dependencies conditionally using mkMerge
    systemd.services.crystal-forge-agent = lib.mkIf cfg.client.enable (lib.mkMerge [
      {
        after = ["crystal-forge-setup.service"];
        wants = ["crystal-forge-setup.service"];
        preStart = lib.mkForce "";
      }
    ]);

    systemd.services.crystal-forge-builder = lib.mkIf cfg.build.enable (lib.mkMerge [
      {
        after = ["crystal-forge-setup.service"];
        wants = ["crystal-forge-setup.service"];
        preStart = lib.mkForce "";
      }
    ]);

    systemd.services.crystal-forge-server = lib.mkIf cfg.server.enable (lib.mkMerge [
      {
        after = ["crystal-forge-setup.service"];
        wants = ["crystal-forge-setup.service"];
      }
    ]);

    # Vault agent configuration for fetching the private key
    campground.services = {
      vault-agent = {
        services = {
          "crystal-forge-setup" = {
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
                  "attic-env" = {
                    text = ''
                      ATTIC_SERVER_URL=${cfg.cache.push_to or "https://attic.aicampground.com"}
                      ATTIC_TOKEN={{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.attic_token }}{{ else }}{{ .Data.data.attic_token }}{{ end }}{{ end }}
                      ATTIC_REMOTE_NAME=${cfg.cache.attic_cache_name or "campground"}
                      HOME=/var/lib/crystal-forge
                      XDG_CONFIG_HOME=/var/lib/crystal-forge/.config
                    '';
                    permissions = "0644";
                    change-action = "restart";
                  };
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
