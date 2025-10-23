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
      enable = lib.mkEnableOption "Crystal Forge Server";
      host = lib.mkOption {
        type = lib.types.str;
        default = "0.0.0.0";
        description = "Server bind address";
      };
      port = lib.mkOption {
        type = lib.types.port;
        default = 3000;
        description = "Server port";
      };

      evalWorkers = lib.mkOption {
        type = lib.types.int;
        default = 4;
        description = lib.mdDoc ''
          Number of worker threads for nix-eval-jobs parallel evaluation.
          Set to 0 to automatically use the number of CPU cores available.

          This controls how many systems can be evaluated concurrently
          when processing flake commits.
        '';
      };

      evalMaxMemoryMb = lib.mkOption {
        type = lib.types.int;
        default = 4096;
        description = lib.mdDoc ''
          Maximum memory size per worker in MB for nix-eval-jobs.

          Each evaluation worker will be limited to this amount of memory.
          Default is 4096 MB (4 GB) per worker.

          Adjust based on available system memory and the number of workers.
        '';
      };

      evalCheckCache = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = lib.mdDoc ''
          Whether to check cache status during evaluation.

          When enabled, nix-eval-jobs will report which derivations are
          already built (in local store or binary cache) vs need building.

          Disable if cache checking is slow or causing issues.
        '';
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

      # === BUILD CONCURRENCY SETTINGS ===

      max_concurrent_derivations = lib.mkOption {
        type = lib.types.ints.positive;
        default = 1;
        description = lib.mdDoc ''
          Maximum number of concurrent nix-store --realise processes.

          This controls how many builds Crystal Forge runs in parallel across
          the entire system.

          **Formula for CPU usage:**
          ```
          Max CPU = max_concurrent_derivations × max_jobs × cores_per_job
          ```

          **Default**: 1 (very conservative - one build at a time)

          **Recommended values by system:**
          - 4-8 cores: 1-2
          - 16 cores: 2-3
          - 32 cores: 3-4
          - 64+ cores: 4-8

          ⚠️  Too high = system overload and slowdown
        '';
        example = 3;
      };

      max_jobs = lib.mkOption {
        type = lib.types.ints.positive;
        default = 1;
        description = lib.mdDoc ''
          Number of parallel derivations within each nix-store process.

          Passed as `--max-jobs` to Nix. This is NOT cores per build - it's
          how many different derivations can build simultaneously within a
          single build process.

          **Default**: 1 (sequential derivations within each build)

          **Example**: If max_jobs=2, a single build process can compile
          two different packages at the same time.

          **Recommended values:**
          - Conservative: 1 (one derivation at a time)
          - Moderate: 2-3 (some parallelism)
          - Aggressive: 4-6 (high parallelism, needs many cores)

          ⚠️  Total parallelism = max_concurrent_derivations × max_jobs
        '';
        example = 2;
      };

      cores_per_job = lib.mkOption {
        type = lib.types.ints.unsigned;
        default = 0;
        description = lib.mdDoc ''
          Number of CPU cores each derivation build can use.

          Passed as `--cores` to Nix. Controls how many cores a single
          derivation (e.g., compiling a package) can utilize.

          **Special value 0**: Unrestricted - each derivation can use all
          available cores. This is the Nix default and works well when
          max_concurrent_derivations = 1.

          **Default**: 0 (unrestricted for single builds)

          **Recommended values:**
          - If max_concurrent_derivations = 1: 0 (let it use all cores)
          - If max_concurrent_derivations > 1: Set to avoid oversubscription

          **Formula to avoid oversubscription:**
          ```
          cores_per_job ≤ total_cores / (max_concurrent_derivations × max_jobs)
          ```

          **Example on 32-core system:**
          - max_concurrent_derivations=3, max_jobs=2 → cores_per_job=4
          - (3 × 2 × 4 = 24 cores, leaves 8 for system)

          ⚠️  If 0 with max_concurrent_derivations > 1, you'll oversubscribe CPUs!
        '';
        example = 4;
      };

      # === BINARY CACHE SETTINGS ===

      use_substitutes = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = lib.mdDoc ''
          Whether to use binary substitutes/caches.

          When true, Nix will download pre-built packages from caches
          instead of building them locally.

          **Recommended**: true (much faster builds)
          **Disable if**: Testing local builds or working offline
        '';
      };

      offline = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = lib.mdDoc ''
          Build in offline mode (no network access).

          When true, Nix will not attempt to download anything. Useful
          for air-gapped environments or testing.

          **Note**: Requires all sources to be pre-fetched or in store.
        '';
      };

      # === TIMING SETTINGS ===

      poll_interval = lib.mkOption {
        type = lib.types.str;
        default = "5m";
        description = lib.mdDoc ''
          Interval between checking for new build jobs.

          How often the build coordinator checks the database for new
          derivations to build.

          **Default**: "5m" (5 minutes)
          **For active development**: "5s" (5 seconds)
          **For production**: "1m" - "5m"

          Format: duration string (e.g., "30s", "5m", "1h")
        '';
        example = "30s";
      };

      max_silent_time = lib.mkOption {
        type = lib.types.str;
        default = "1h";
        description = lib.mdDoc ''
          Maximum time a build can be silent before timing out.

          If a build produces no output for this duration, it will be
          killed. Prevents hung builds from consuming resources.

          **Default**: "1h" (1 hour)

          **Adjust for:**
          - Large builds (Firefox, Chromium): "2h" or more
          - Small packages: "30m"

          Format: duration string (e.g., "30m", "2h")
        '';
        example = "2h";
      };

      timeout = lib.mkOption {
        type = lib.types.str;
        default = "2h";
        description = lib.mdDoc ''
          Maximum total time for a build before timing out.

          The absolute maximum time any build can run, regardless of
          whether it's producing output.

          **Default**: "2h" (2 hours)

          **Adjust for:**
          - Very large builds (LLVM, WebKit): "6h" or more
          - Typical packages: "1h" - "3h"

          Format: duration string (e.g., "1h", "6h")
        '';
        example = "6h";
      };

      # === SECURITY SETTINGS ===

      sandbox = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = lib.mdDoc ''
          Enable sandbox for builds.

          When true, builds run in an isolated environment with restricted
          network and filesystem access. This is a security best practice.

          **Recommended**: true (always)
          **Disable only if**: Build requires network access (rare, usually wrong)
        '';
      };

      # === SYSTEMD RESOURCE ISOLATION ===

      use_systemd_scope = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = lib.mdDoc ''
          Whether to use systemd-run for resource isolation.

          When enabled, each build runs in a systemd scope with enforced
          resource limits (memory, CPU). This prevents runaway builds from
          taking down the entire system.

          **Benefits:**
          - Memory limits prevent OOM kills of main process
          - CPU quotas prevent one build from starving others
          - Automatic cleanup of build processes

          **Requires**: systemd (works on NixOS, most Linux distros)

          **Fallback**: If systemd-run fails, builds run directly

          **Recommended**: true (critical for production)
        '';
      };

      systemd_memory_max = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = "32G";
        description = lib.mdDoc ''
          Memory limit for each build scope.

          Maximum amount of RAM a single build scope can use. When
          exceeded, the scope's processes will be OOM-killed, protecting
          the main Crystal Forge process.

          **Formula:**
          ```
          Total memory usage ≤ max_concurrent_derivations × systemd_memory_max
          ```

          **Default**: "32G" (32 GB per build)

          **Recommended values:**
          - 16GB system: "4G" per build
          - 32GB system: "8G" - "16G" per build
          - 64GB system: "16G" - "32G" per build
          - 128GB+ system: "32G" - "64G" per build

          **Large builds (LLVM, Chromium)**: May need 16GB+

          Format: suffixed size (e.g., "4G", "2048M", "8192M")

          Set to `null` to disable memory limits (not recommended).
        '';
        example = "16G";
      };

      systemd_cpu_quota = lib.mkOption {
        type = lib.types.nullOr lib.types.ints.positive;
        default = 800;
        description = lib.mdDoc ''
          CPU quota for each build scope as percentage.

          Limits the total CPU time available to an entire build scope
          (which may run multiple derivations via max_jobs).

          **Value**: Percentage × 100 (e.g., 400 = 4 cores, 800 = 8 cores)

          **Default**: 800 (8 cores per build scope)

          **Formula for setting:**
          ```
          systemd_cpu_quota ≥ (max_jobs × cores_per_job) × 100
          ```

          **Example:**
          - max_jobs=2, cores_per_job=4 → systemd_cpu_quota should be ≥ 800

          **Recommended values:**
          - Small systems: 200-400 (2-4 cores per build)
          - Medium systems: 400-800 (4-8 cores per build)
          - Large systems: 800-1200 (8-12 cores per build)

          ⚠️  If too low, builds will be throttled even if cores are free

          Set to `null` to disable CPU quotas (not recommended).
        '';
        example = 600;
      };

      systemd_timeout_stop_sec = lib.mkOption {
        type = lib.types.nullOr lib.types.ints.positive;
        default = 600;
        description = lib.mdDoc ''
          Timeout for systemd scope stop operation in seconds.

          How long systemd will wait for a build scope to stop gracefully
          before force-killing it.

          **Default**: 600 (10 minutes)

          **Recommended values:**
          - Quick builds: 300 (5 minutes)
          - Normal builds: 600 (10 minutes)
          - Large builds: 900 (15 minutes)

          ⚠️  Too short = premature kills during cleanup
          ⚠️  Too long = delays in canceling stuck builds
        '';
        example = 900;
      };

      systemd_properties = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "MemorySwapMax=2G"
          "TasksMax=3000"
        ];
        description = lib.mdDoc ''
          Additional systemd properties to set for build scopes.

          These are passed as `--property` arguments to systemd-run.
          Only certain properties are valid for scopes.

          **Default properties:**
          - `MemorySwapMax=2G`: Limit swap usage
          - `TasksMax=3000`: Limit number of processes/threads

          **Valid property prefixes for scopes:**
          - Memory* (MemoryMax, MemorySwapMax, MemoryHigh, etc.)
          - CPU* (CPUQuota, CPUWeight, etc.)
          - Tasks* (TasksMax)
          - IO* (IOWeight, IOReadBandwidthMax, etc.)
          - Kill* (KillMode, KillSignal)
          - OOM* (OOMPolicy, OOMScoreAdjust)
          - Device* (DevicePolicy, DeviceAllow)
          - IPAccounting* (IPAccounting, IPAddressAllow, etc.)

          **Note**: Service-only properties (Environment, Restart,
          WorkingDirectory) are ignored for scopes.
        '';
        example = [
          "MemorySwapMax=4G"
          "TasksMax=5000"
          "IOWeight=100"
          "CPUWeight=100"
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
    deployment = {
      max_deployment_age_minutes = lib.mkOption {
        type = lib.types.ints.unsigned;
        default = 30;
        description = "Maximum age in minutes for deployments to be considered valid";
      };
      dry_run_first = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Perform a dry run before actual deployment";
      };
      fallback_to_local_build = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Fallback to local build if remote build fails";
      };
      deployment_timeout_minutes = lib.mkOption {
        type = lib.types.ints.unsigned;
        default = 60;
        description = "Timeout for deployment operations in minutes";
      };
      cache_url = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Cache URL for deployment artifacts";
      };
      cache_public_key = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Public key for verifying cache signatures (used in trusted-public-keys)";
      };
      deployment_poll_interval = lib.mkOption {
        type = lib.types.str;
        default = "15m";
        description = "Interval between deployment polling checks";
      };
    };
    cache = {
      attic_cache_name = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Attic cache name";
      };
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
      poll_interval = lib.mkOption {
        type = lib.types.ints.unsigned;
        default = 5;
        description = "Delay between cache pushes in seconds";
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
          desired_target = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Desired derivation hash for system";
          };
          deployment_policy = lib.mkOption {
            type = lib.types.enum ["manual" "auto_latest" "pinned"];
            default = "manual";
            description = "Deployment policy for the system";
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
          desired_target = null;
          deployment_policy = "manual";
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
      inherit (cfg) flakes systems environments vulnix cache auth deployment;

      build =
        cfg.build
        // {
          systemd_properties = cfg.build.systemd_properties or [];
        };
    };

    systemd.tmpfiles.rules = [
      "d /var/lib/crystal-forge 0755 crystal-forge crystal-forge -"
      "d /var/lib/crystal-forge/.cache 0755 crystal-forge crystal-forge -"
      "d /var/lib/crystal-forge/.cache/nix 0755 crystal-forge crystal-forge -"
      "d /var/lib/crystal-forge/tmp 0755 crystal-forge crystal-forge -"
      "d /var/lib/crystal-forge/builds 0755 crystal-forge crystal-forge -"
      "d /var/lib/crystal-forge/workdir 0755 crystal-forge crystal-forge -"
      "d /var/lib/crystal-forge/.ssh 0700 crystal-forge crystal-forge -"
      "f /var/lib/crystal-forge/config.toml 0600 crystal-forge crystal-forge - -"
      "d /var/lib/crystal-forge/.config 0755 crystal-forge crystal-forge -"
      "d /var/lib/crystal-forge/.config/attic 0755 crystal-forge crystal-forge -"
      "d /var/lib/crystal-forge/.config/nix 0755 crystal-forge crystal-forge -"
      "d /var/lib/crystal-forge/.local 0755 crystal-forge crystal-forge -"
      "d /var/lib/crystal-forge/.local/share 0755 crystal-forge crystal-forge -"
    ];

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

        ${lib.optionalString (cfg.build.enable && cfg.cache.cache_type == "Attic" && cfg.cache.push_to != null) ''
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
          mkdir -p /var/lib/crystal-forge/.config
          cp /tmp/detsys-vault/attic-env /var/lib/crystal-forge/.config/crystal-forge-attic.env
          chmod 644 /var/lib/crystal-forge/.config/crystal-forge-attic.env
          echo "✅ Attic environment file copied successfully"
        ''}

        ${lib.optionalString (cfg.build.enable && cfg.cache.cache_type == "S3" && cfg.cache.push_to != null) ''
          # Wait for and copy S3 environment file
          echo "Waiting for vault-agent to create s3-env..."
          elapsed=0
          while [ ! -f /tmp/detsys-vault/s3-env ] && [ $elapsed -lt $timeout ]; do
            sleep 2
            elapsed=$((elapsed + 2))
          done
          if [ ! -f /tmp/detsys-vault/s3-env ]; then
            echo "ERROR: s3-env not found after $timeout seconds"
            exit 1
          fi
          mkdir -p /var/lib/crystal-forge/.config
          cp /tmp/detsys-vault/s3-env /var/lib/crystal-forge/.config/crystal-forge-s3.env
          chmod 644 /var/lib/crystal-forge/.config/crystal-forge-s3.env
          echo "✅ S3 environment file copied successfully"

          # Wait for and copy signing key
          echo "Waiting for vault-agent to create signing-key..."
          elapsed=0
          while [ ! -f /tmp/detsys-vault/signing-key ] && [ $elapsed -lt $timeout ]; do
            sleep 2
            elapsed=$((elapsed + 2))
          done
          if [ ! -f /tmp/detsys-vault/signing-key ]; then
            echo "ERROR: signing-key not found after $timeout seconds"
            exit 1
          fi
          cp /tmp/detsys-vault/signing-key /var/lib/crystal-forge/signing-key
          chmod 600 /var/lib/crystal-forge/signing-key
          chown crystal-forge:crystal-forge /var/lib/crystal-forge/signing-key
          echo "✅ Signing key copied successfully"
        ''}

        echo "Crystal Forge setup completed successfully"
      '';
    };

    # Update service dependencies conditionally using mkMerge
    systemd.services.crystal-forge-agent = lib.mkIf cfg.client.enable (lib.mkMerge [
      {
        after = ["crystal-forge-setup.service"];
        wants = ["crystal-forge-setup.service"];
      }
    ]);

    systemd.services.crystal-forge-builder = lib.mkIf cfg.build.enable (lib.mkMerge [
      {
        after = ["crystal-forge-setup.service"];
        wants = ["crystal-forge-setup.service"];
        serviceConfig = {
          ReadWritePaths = [
            "/var/lib/crystal-forge"
            "/tmp"
            "/run/crystal-forge"
            "/var/cache/crystal-forge-nix"
          ];
          # List format with - prefix for optional files
          EnvironmentFile =
            lib.optionals (cfg.cache.cache_type == "S3" && cfg.cache.push_to != null) [
              "-/var/lib/crystal-forge/.config/crystal-forge-s3.env"
            ]
            ++ lib.optionals (cfg.cache.cache_type == "Attic" && cfg.cache.push_to != null) [
              "-/var/lib/crystal-forge/.config/crystal-forge-attic.env"
            ];
        };
      }
    ]);

    systemd.services.crystal-forge-server = lib.mkIf cfg.server.enable (lib.mkMerge [
      {
        after = ["crystal-forge-setup.service"];
        wants = ["crystal-forge-setup.service"];
        # environment = {
        #   CRYSTAL_FORGE__CLIENT__EVAL_WORKERS = "8";
        #   CRYSTAL_FORGE__CLIENT__EVAL_MAX_MEMORY_MB = "3096";
        # };
        serviceConfig = {
          ReadWritePaths = [
            "/var/lib/crystal-forge"
            "/tmp"
            "/run/crystal-forge"
            "/var/cache/crystal-forge-nix"
          ];
          # No EnvironmentFile needed for server
        };
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
                  "attic-env" = lib.mkIf (cfg.cache.cache_type == "Attic" && cfg.cache.push_to != null) {
                    text = ''
                      ATTIC_SERVER_URL=${cfg.cache.push_to}
                      ATTIC_TOKEN={{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.attic_token }}{{ else }}{{ .Data.data.attic_token }}{{ end }}{{ end }}
                      ATTIC_REMOTE_NAME=${cfg.cache.attic_cache_name}
                      HOME=/var/lib/crystal-forge
                      XDG_CONFIG_HOME=/var/lib/crystal-forge/.config
                    '';
                    permissions = "0644";
                    change-action = "restart";
                  };

                  "s3-env" = lib.mkIf (cfg.cache.cache_type == "S3" && cfg.cache.push_to != null) {
                    text = ''
                      AWS_ACCESS_KEY_ID={{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.minio_access_key }}{{ else }}{{ .Data.data.minio_access_key }}{{ end }}{{ end }}
                      AWS_SECRET_ACCESS_KEY={{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.minio_secret_key }}{{ else }}{{ .Data.data.minio_secret_key }}{{ end }}{{ end }}
                      ${lib.optionalString (cfg.cache.s3_region != null) "AWS_REGION=${cfg.cache.s3_region}"}
                      AWS_EC2_METADATA_DISABLED=true
                      HOME=/var/lib/crystal-forge
                      XDG_CONFIG_HOME=/var/lib/crystal-forge/.config
                    '';
                    permissions = "0644";
                    change-action = "restart";
                  };

                  "signing-key" = lib.mkIf (cfg.cache.cache_type == "S3" && cfg.cache.push_to != null) {
                    text = ''
                      {{ with secret "${cfg.vault-path}" }}
                      {{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.signing_key }}{{ else }}{{ .Data.data.signing_key }}{{ end }}
                      {{ end }}
                    '';
                    permissions = "0600";
                    change-action = "restart";
                  };

                  "agent.key" = {
                    text = ''
                      {{ with secret "${cfg.vault-path}" }}
                      {{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.${host} }}{{ else }}{{ .Data.data.${host} }}{{ end }}
                      {{ end }}
                    '';
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
