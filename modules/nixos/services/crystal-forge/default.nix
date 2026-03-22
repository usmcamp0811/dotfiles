{ lib, config, pkgs, ... }:
with lib;
with lib.fmf;
let
  cfg = config.fmf.services.crystal-forge;
  host = config.networking.hostName;
  authentikIssuer =
    "${cfg.authentik.baseUrl}/application/o/${cfg.authentik.providerSlug}/";
  effectiveOidcEnabled = cfg.server.enable
    && (cfg.authentik.enable || cfg.server.auth_mode == "oidc");
  effectiveOidcClientSecretFile = if cfg.authentik.enable then
    cfg.authentik.clientSecretFile
  else
    cfg.server.oidc.clientSecretFile;
in {
  options.fmf.services.crystal-forge = {
    enable = mkEnableOption "Enable the Crystal Forge service(s)";

    log_level = lib.mkOption {
      type = lib.types.enum [ "off" "error" "warn" "info" "debug" "trace" ];
      default = "info";
      description = "Log level for all Crystal Forge components.";
    };

    configPath = mkOption {
      type = types.path;
      default = "/var/lib/crystal-forge/config.toml";
      description = "Path to the final config.toml file.";
    };

    # === Database (matches upstream) ===
    database = {
      host = mkOption {
        type = types.str;
        default = "localhost";
      };
      port = mkOption {
        type = types.port;
        default = 5432;
      };
      user = mkOption {
        type = types.str;
        default = "crystal_forge";
      };
      password = mkOption {
        type = types.str;
        default = "password";
        description = "Used only if passwordFile is null.";
      };
      passwordFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description =
          "Optional path to a file containing the DB password. Overrides 'password'.";
      };
      name = mkOption {
        type = types.str;
        default = "crystal_forge";
      };
    };

    # === Server (names match upstream exactly) ===
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
      auth_mode = lib.mkOption {
        type = lib.types.enum [ "local" "oidc" ];
        default = "local";
        description = "Authentication mode for Crystal Forge server.";
      };
      oidc = {
        issuerUrl = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "OIDC issuer URL.";
        };
        clientId = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "OIDC client ID.";
        };
        clientSecret = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "OIDC client secret (prefer clientSecretFile).";
        };
        clientSecretFile = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          description = "Path to file containing OIDC client secret.";
        };
        clientSecretVaultField = lib.mkOption {
          type = lib.types.str;
          default = "CLIENT_SECRET";
          description =
            "Vault field name used to render the OIDC client secret file.";
        };
        redirectUri = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "OIDC callback URL for Crystal Forge.";
        };
        scopes = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ "openid" "profile" "email" ];
          description = "OIDC scopes requested during login.";
        };
        emailClaim = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
        };
        nameClaim = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
        };
        givenNameClaim = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
        };
        familyNameClaim = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
        };
        rolesClaim = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
        };
        preferredUsernameClaim = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
        };
        bootstrapAdminGroup = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description =
            "OIDC group name that should automatically receive Admin role.";
        };
      };
      eval_workers = lib.mkOption {
        type = lib.types.int;
        default = 4;
        description = "Parallel nix-eval-jobs workers (0 = CPU cores).";
      };
      eval_max_memory_mb = lib.mkOption {
        type = lib.types.int;
        default = 4096;
        description = "Memory limit (MB) per nix-eval-jobs worker.";
      };
      eval_check_cache = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to check cache status during evaluation.";
      };
      role_mapping = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
        example = {
          "Admins" = "admin";
          "Developers" = "user";
        };
        description = ''
          Mapping from OIDC group/role claim values to Crystal Forge roles.
          Keys are the group names from the identity provider, values are
          the Crystal Forge role names (e.g., "admin", "user").
        '';
      };
    };

    authentik = {
      enable =
        mkBoolOpt false "Configure Crystal Forge OIDC settings for Authentik.";
      baseUrl = mkOpt types.str "https://auth.aicampground.com"
        "Base URL for Authentik.";
      providerSlug = mkOpt types.str "crystal-forge"
        "Authentik provider/application slug used in OIDC endpoints.";
      clientId = mkOpt types.str "crystal-forge-web"
        "OIDC client ID created in Authentik.";
      redirectUri = mkOpt (types.nullOr types.str) null
        "OIDC redirect URI for Crystal Forge (required when Authentik support is enabled).";
      scopes = mkOpt (types.listOf types.str) [ "openid" "profile" "email" ]
        "OIDC scopes for Authentik login.";
      rolesClaim = mkOpt (types.nullOr types.str) "groups"
        "Claim name for Authentik roles/groups.";
      emailClaim =
        mkOpt (types.nullOr types.str) "email" "Claim name for user email.";
      nameClaim =
        mkOpt (types.nullOr types.str) "name" "Claim name for display name.";
      preferredUsernameClaim =
        mkOpt (types.nullOr types.str) "preferred_username"
        "Claim name for preferred username.";
      clientSecretFile = mkOpt (types.nullOr types.path)
        "/var/lib/crystal-forge/oidc-client-secret"
        "Path for Authentik OIDC client secret.";
      bootstrapAdminGroup = mkOpt (types.nullOr types.str) null
        "Authentik group name that should automatically receive Admin role on bootstrap.";
    };

    # === Auth (matches upstream) ===
    auth = {
      ssh_key_path = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description =
          "SSH private key for Git auth. If null, a key may be generated.";
      };
      ssh_known_hosts_path = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = "/var/lib/crystal-forge/.ssh/known_hosts";
        description = "Path to SSH known_hosts file.";
      };
      netrc_path = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = "/var/lib/crystal-forge/.netrc";
        description = "Path to .netrc file for HTTPS Git auth.";
      };
      ssh_disable_strict_host_checking = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Disable StrictHostKeyChecking for SSH fetches.";
      };
    };

    # === Agent (client) (matches upstream) ===
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
        description = "Path to Ed25519 private key for agent auth.";
      };
    };

    # === Flakes (matches upstream) ===
    flakes = {
      watched = lib.mkOption {
        type = lib.types.listOf (lib.types.submodule {
          options = {
            name = lib.mkOption {
              type = lib.types.str;
              description = "Logical name for the flake";
            };
            repo_url = lib.mkOption {
              type = lib.types.str;
              description = "Repository URL";
            };
            auto_poll = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "Automatically poll for new commits.";
            };
            initial_commit_depth = lib.mkOption {
              type = lib.types.ints.positive;
              default = 10;
              description = "Initial commit history to import.";
            };
          };
        });
        default = [ ];
        description = "Flakes to watch for changes.";
      };
      flake_polling_interval = lib.mkOption {
        type = lib.types.str;
        default = "10m";
      };
      commit_evaluation_interval = lib.mkOption {
        type = lib.types.str;
        default = "1m";
      };
      build_processing_interval = lib.mkOption {
        type = lib.types.str;
        default = "1m";
      };
    };

    # === Build (matches upstream) ===
    build = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = cfg.server.enable;
        description = "Crystal Forge Builder";
      };

      max_concurrent_derivations = lib.mkOption {
        type = lib.types.ints.positive;
        default = 1;
      };
      max_jobs = lib.mkOption {
        type = lib.types.ints.positive;
        default = 1;
      };
      cores_per_job = lib.mkOption {
        type = lib.types.ints.unsigned;
        default = 0;
      };

      use_substitutes = lib.mkOption {
        type = lib.types.bool;
        default = true;
      };
      offline = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };

      poll_interval = lib.mkOption {
        type = lib.types.str;
        default = "5m";
      };
      max_silent_time = lib.mkOption {
        type = lib.types.str;
        default = "1h";
      };
      timeout = lib.mkOption {
        type = lib.types.str;
        default = "2h";
      };

      sandbox = lib.mkOption {
        type = lib.types.bool;
        default = true;
      };
      use_systemd_scope = lib.mkOption {
        type = lib.types.bool;
        default = true;
      };

      systemd_memory_max = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = "32G";
      };
      systemd_cpu_quota = lib.mkOption {
        type = lib.types.nullOr lib.types.ints.positive;
        default = 800;
      };
      systemd_timeout_stop_sec = lib.mkOption {
        type = lib.types.nullOr lib.types.ints.positive;
        default = 600;
      };
      systemd_properties = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ "MemorySwapMax=2G" "TasksMax=3000" ];
      };
    };

    # === Builder API mode (upstream builder.* config) ===
    builder = {
      enable_api_mode = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Crystal Forge builder API mode.";
      };
      builder_id = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description =
          "Builder UUID used when the builder authenticates to the Crystal Forge API.";
      };
      server_url = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Crystal Forge API base URL for builder API mode.";
      };
      private_key_path = lib.mkOption {
        type = lib.types.path;
        default = "/var/lib/crystal-forge/builder-api.key";
        description =
          "Path to the Ed25519 private key used by builder API mode.";
      };
      private_key_vault_field = lib.mkOption {
        type = lib.types.str;
        default = "${host}-builder";
        description =
          "Vault field name used to render the builder API private key.";
      };
      poll_interval = lib.mkOption {
        type = lib.types.ints.unsigned;
        default = 5;
        description = "Builder API job poll interval in seconds.";
      };
      heartbeat_interval = lib.mkOption {
        type = lib.types.ints.unsigned;
        default = 30;
        description = "Builder API heartbeat interval in seconds.";
      };
      max_concurrent_jobs = lib.mkOption {
        type = lib.types.nullOr lib.types.ints.positive;
        default = null;
        description =
          "Optional maximum concurrent jobs override for builder API mode.";
      };
    };

    # === Vulnix (matches upstream) ===
    vulnix = {
      timeout = lib.mkOption {
        type = lib.types.str;
        default = "5m";
      };
      max_retries = lib.mkOption {
        type = lib.types.ints.unsigned;
        default = 5;
      };
      enable_whitelist = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };
      extra_args = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
      };
      whitelist_path = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
      };
      poll_interval = lib.mkOption {
        type = lib.types.str;
        default = "1m";
      };
    };

    # === Cache (matches upstream completely) ===
    cache = {
      cache_type = lib.mkOption {
        type = lib.types.enum [ "S3" "Attic" "Http" "Nix" ];
        default = "Nix";
      };
      push_to = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
      };
      push_after_build = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };
      signing_key = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = "/var/lib/crystal-forge/signing-key";
      };
      compression = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
      };
      push_filter = lib.mkOption {
        type = lib.types.nullOr (lib.types.listOf lib.types.str);
        default = null;
      };
      parallel_uploads = lib.mkOption {
        type = lib.types.ints.positive;
        default = 4;
      };

      # S3
      s3_region = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
      };
      s3_profile = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
      };

      # Attic
      attic_token = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
      };
      attic_cache_name = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
      };
      attic_ignore_upstream_cache_filter = lib.mkOption {
        type = lib.types.bool;
        default = true;
      };
      attic_jobs = lib.mkOption {
        type = lib.types.ints.unsigned;
        default = 5;
      };

      # Retries
      max_retries = lib.mkOption {
        type = lib.types.ints.unsigned;
        default = 3;
      };
      retry_delay_seconds = lib.mkOption {
        type = lib.types.ints.unsigned;
        default = 5;
      };
      poll_interval = lib.mkOption {
        type = lib.types.ints.unsigned;
        default = 5;
      };
      force_repush = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };
    };

    # === Deployment (matches upstream) ===
    deployment = {
      max_deployment_age_minutes = lib.mkOption {
        type = lib.types.ints.unsigned;
        default = 30;
      };
      dry_run_first = lib.mkOption {
        type = lib.types.bool;
        default = true;
      };
      fallback_to_local_build = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };
      deployment_timeout_minutes = lib.mkOption {
        type = lib.types.ints.unsigned;
        default = 60;
      };
      cache_url = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
      };
      cache_public_key = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
      };
      deployment_poll_interval = lib.mkOption {
        type = lib.types.str;
        default = "15m";
      };
      require_sigs = lib.mkOption {
        type = lib.types.bool;
        default = true;
      };
    };

    # === Systems (matches upstream) ===
    systems = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule {
        options = {
          hostname = lib.mkOption {
            type = lib.types.str;
            description = "System hostname";
          };
          public_key = lib.mkOption {
            type = lib.types.str;
            description = "Base64 Ed25519 pubkey";
          };
          environment = lib.mkOption {
            type = lib.types.str;
            description = "Environment name";
          };
          flake_name = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
          };
          desired_target = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
          };
          deployment_policy = lib.mkOption {
            type = lib.types.enum [ "manual" "auto_latest" "pinned" ];
            default = "manual";
          };
        };
      });
      default = [ ];
      description = "Systems to register.";
    };

    # === Environments (matches upstream) ===
    environments = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule {
        options = {
          name = lib.mkOption { type = lib.types.str; };
          description = lib.mkOption { type = lib.types.str; };
          is_active = lib.mkOption { type = lib.types.bool; };
          risk_profile = lib.mkOption { type = lib.types.str; };
          compliance_level = lib.mkOption { type = lib.types.str; };
        };
      });
      default = [ ];
      description = "List of environments.";
    };

    # === Dashboards (whole block matches upstream) ===
    dashboards = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description =
          "Enable Grafana datasource + dashboards for Crystal Forge.";
      };

      datasource = {
        name = lib.mkOption {
          type = lib.types.str;
          default = "Crystal Forge PostgreSQL";
        };
        host = lib.mkOption {
          type = lib.types.str;
          default = cfg.database.host;
          defaultText = lib.literalExpression
            "config.fmf.services.crystal-forge.database.host";
        };
        port = lib.mkOption {
          type = lib.types.port;
          default = cfg.database.port;
          defaultText = lib.literalExpression
            "config.fmf.services.crystal-forge.database.port";
        };
        database = lib.mkOption {
          type = lib.types.str;
          default = cfg.database.name;
          defaultText = lib.literalExpression
            "config.fmf.services.crystal-forge.database.name";
        };
        user = lib.mkOption {
          type = lib.types.str;
          default = "grafana";
        };
        passwordFile = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
        };
        sslMode = lib.mkOption {
          type =
            lib.types.enum [ "disable" "require" "verify-ca" "verify-full" ];
          default = "disable";
        };
      };

      grafana = {
        provision = lib.mkOption {
          type = lib.types.bool;
          default = true;
        };
        disableDeletion = lib.mkOption {
          type = lib.types.bool;
          default = true;
        };
      };
    };

    # === Misc ===
    local-database = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to set up and manage a local PostgreSQL database";
    };

    # Used by upstream for dynamic ATTIC_TOKEN injection
    env-file = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/crystal-forge/.config/crystal-forge-attic.env";
      description =
        "Optional env file path (used by builder to source ATTIC_TOKEN, etc.)";
    };

    # === Vault Agent glue (keep exactly as your downstream requires) ===
    role-id =
      mkOpt types.str config.fmf.services.vault-agent.settings.vault.role-id
      "Absolute path to the Vault role-id";
    secret-id =
      mkOpt types.str config.fmf.services.vault-agent.settings.vault.secret-id
      "Absolute path to the Vault secret-id";
    vault-path = mkOpt types.str "secret/campground/crystal-forge"
      "KV path containing CF secrets (attic token, s3 keys, per-host agent keys, etc.)";
    kvVersion = mkOption {
      type = types.enum [ "v1" "v2" ];
      default = "v2";
      description = "Vault KV store version";
    };
    vault-address = mkOption {
      type = types.str;
      default = config.fmf.services.vault-agent.settings.vault.address;
      description = "Vault address";
    };
  };

  # =========================
  # Config: pure passthrough
  # =========================
  config = mkIf cfg.enable {
    services.crystal-forge = {
      enable = true;

      inherit (cfg)
        log_level database local-database auth flakes systems environments
        vulnix cache deployment dashboards;

      server = mkIf cfg.server.enable ({
        enable = true;
        inherit (cfg.server)
          host port auth_mode eval_workers eval_max_memory_mb eval_check_cache
          role_mapping;
        oidc = {
          inherit (cfg.server.oidc)
            issuerUrl clientId clientSecret clientSecretFile redirectUri scopes
            emailClaim nameClaim givenNameClaim familyNameClaim rolesClaim
            preferredUsernameClaim bootstrapAdminGroup;
        };
      } // lib.optionalAttrs cfg.authentik.enable {
        auth_mode = "oidc";
        oidc = {
          issuerUrl = authentikIssuer;
          clientId = cfg.authentik.clientId;
          clientSecretFile = cfg.authentik.clientSecretFile;
          redirectUri = cfg.authentik.redirectUri;
          scopes = cfg.authentik.scopes;
          rolesClaim = cfg.authentik.rolesClaim;
          emailClaim = cfg.authentik.emailClaim;
          nameClaim = cfg.authentik.nameClaim;
          preferredUsernameClaim = cfg.authentik.preferredUsernameClaim;
          bootstrapAdminGroup = cfg.authentik.bootstrapAdminGroup;
        };
      });

      client = mkIf cfg.client.enable {
        enable = true;
        inherit (cfg.client) server_host server_port;
        # Always give upstream a concrete path; we provision the file below.
        private_key = "/var/lib/crystal-forge-agent/agent.key";
      };

      # build is mostly pass-through; ensure systemd_properties always present
      build = (cfg.build or { }) // {
        systemd_properties = cfg.build.systemd_properties or [ ];
      };
    };

    # ---- File/dir scaffolding (agent key, cache envs, etc.) ----
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
      # agent-side
      "d /var/lib/crystal-forge-agent 0750 root root -"
      "f /var/lib/crystal-forge-agent/agent.key 0600 root root - -"
      "f ${
        toString cfg.builder.private_key_path
      } 0600 crystal-forge crystal-forge - -"
    ];

    # ---- Simple setup step to copy Vault-rendered files into place ----
    systemd.services.crystal-forge-setup =
      mkIf (config.fmf.services.vault-agent.enable) {
        description = "Crystal Forge Setup - Copy Vault Agent Files";
        wantedBy = [ "multi-user.target" ];
        after = [ "vault-agent-crystal-forge-setup.service" ];
        wants = [ "vault-agent-crystal-forge-setup.service" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          User = "root";
          Group = "root";
        };
        script = ''
          set -euo pipefail
          echo "Starting Crystal Forge setup..."

          mkdir -p /var/lib/crystal-forge-agent

          ${lib.optionalString cfg.client.enable ''
            echo "Waiting for Vault agent to render agent.key..."
            timeout=300
            elapsed=0
            while [ ! -f /tmp/detsys-vault/agent.key ] && [ $elapsed -lt $timeout ]; do
              sleep 2
              elapsed=$((elapsed+2))
            done
            if [ ! -f /tmp/detsys-vault/agent.key ]; then
              echo "ERROR: agent.key not found after $timeout seconds"
              exit 1
            fi
            install -m0600 /tmp/detsys-vault/agent.key /var/lib/crystal-forge-agent/agent.key
            echo "✅ Agent key installed"
          ''}

          ${lib.optionalString
          (cfg.build.enable && cfg.builder.enable_api_mode) ''
            echo "Waiting for Vault agent to render builder.key..."
            timeout=300
            elapsed=0
            while [ ! -f /tmp/detsys-vault/builder.key ] && [ $elapsed -lt $timeout ]; do
              sleep 2
              elapsed=$((elapsed+2))
            done
            if [ ! -f /tmp/detsys-vault/builder.key ]; then
              echo "ERROR: builder.key not found after $timeout seconds"
              exit 1
            fi
            mkdir -p "$(dirname ${
              escapeShellArg (toString cfg.builder.private_key_path)
            })"
            install -o crystal-forge -g crystal-forge -m0600 /tmp/detsys-vault/builder.key ${
              escapeShellArg (toString cfg.builder.private_key_path)
            }
            echo "✅ Builder API key installed"
          ''}

          ${lib.optionalString (cfg.build.enable && cfg.cache.cache_type
            == "Attic" && cfg.cache.push_to != null) ''
              mkdir -p /var/lib/crystal-forge/.config
              if [ -f /tmp/detsys-vault/attic-env ]; then
                install -o crystal-forge -g crystal-forge -m0644 /tmp/detsys-vault/attic-env /var/lib/crystal-forge/.config/crystal-forge-attic.env
                echo "✅ Attic env installed"
              fi
            ''}

          ${lib.optionalString (cfg.build.enable && cfg.cache.cache_type == "S3"
            && cfg.cache.push_to != null) ''
              mkdir -p /var/lib/crystal-forge/.config
              if [ -f /tmp/detsys-vault/s3-env ]; then
                install -o crystal-forge -g crystal-forge -m0644 /tmp/detsys-vault/s3-env /var/lib/crystal-forge/.config/crystal-forge-s3.env
                echo "✅ S3 env installed"
              fi
              if [ -f /tmp/detsys-vault/signing-key ]; then
                install -o crystal-forge -g crystal-forge -m0600 /tmp/detsys-vault/signing-key /var/lib/crystal-forge/signing-key
                echo "✅ Signing key installed"
              fi
            ''}

          ${lib.optionalString
          (effectiveOidcEnabled && effectiveOidcClientSecretFile != null) ''
            echo "Waiting for Vault agent to render oidc-client-secret..."
            timeout=300
            elapsed=0
            while [ ! -f /tmp/detsys-vault/oidc-client-secret ] && [ $elapsed -lt $timeout ]; do
              sleep 2
              elapsed=$((elapsed+2))
            done
            if [ ! -f /tmp/detsys-vault/oidc-client-secret ]; then
              echo "ERROR: oidc-client-secret not found after $timeout seconds"
              exit 1
            fi
              mkdir -p "$(dirname ${
                escapeShellArg (toString effectiveOidcClientSecretFile)
              })"
              install -o crystal-forge -g crystal-forge -m0600 /tmp/detsys-vault/oidc-client-secret ${
                escapeShellArg (toString effectiveOidcClientSecretFile)
              }
              echo "✅ OIDC client secret installed"
          ''}

          echo "Crystal Forge setup completed"
        '';
      };

    # Wire ordering so upstream units see the files
    systemd.services.crystal-forge-agent =
      lib.mkIf (cfg.client.enable && config.fmf.services.vault-agent.enable) {
        after = [ "crystal-forge-setup.service" ];
        wants = [ "crystal-forge-setup.service" ];
      };
    systemd.services.crystal-forge-builder =
      lib.mkIf (cfg.build.enable && config.fmf.services.vault-agent.enable) {
        after =
          [ "crystal-forge-setup.service" "crystal-forge-server.service" ];
        wants = [ "crystal-forge-setup.service" ];
        serviceConfig = {
          PermissionsStartOnly = true;
          ReadWritePaths = [
            "/var/lib/crystal-forge"
            "/tmp"
            "/run/crystal-forge"
            "/var/cache/crystal-forge-nix"
          ];
          EnvironmentFile = lib.optionals
            (cfg.cache.cache_type == "S3" && cfg.cache.push_to != null)
            [ "-/var/lib/crystal-forge/.config/crystal-forge-s3.env" ]
            ++ lib.optionals
            (cfg.cache.cache_type == "Attic" && cfg.cache.push_to != null)
            [ "-/var/lib/crystal-forge/.config/crystal-forge-attic.env" ];
          Environment = lib.optionals cfg.builder.enable_api_mode [
            "CRYSTAL_FORGE__BUILDER__ENABLE_API_MODE=true"
            "CRYSTAL_FORGE__BUILDER__PRIVATE_KEY_PATH=${
              toString cfg.builder.private_key_path
            }"
            "CRYSTAL_FORGE__BUILDER__POLL_INTERVAL=${
              toString cfg.builder.poll_interval
            }"
            "CRYSTAL_FORGE__BUILDER__HEARTBEAT_INTERVAL=${
              toString cfg.builder.heartbeat_interval
            }"
          ] ++ lib.optionals (cfg.builder.builder_id != null)
            [ "CRYSTAL_FORGE__BUILDER__BUILDER_ID=${cfg.builder.builder_id}" ]
            ++ lib.optionals (cfg.builder.server_url != null)
            [ "CRYSTAL_FORGE__BUILDER__SERVER_URL=${cfg.builder.server_url}" ]
            ++ lib.optionals (cfg.builder.max_concurrent_jobs != null) [
              "CRYSTAL_FORGE__BUILDER__MAX_CONCURRENT_JOBS=${
                toString cfg.builder.max_concurrent_jobs
              }"
            ];
        };
      };
    systemd.services.crystal-forge-server = lib.mkIf cfg.server.enable {
      after = [ "crystal-forge-setup.service" ];
      wants = [ "crystal-forge-setup.service" ];
      serviceConfig = {
        PermissionsStartOnly = true;
        ReadWritePaths = [
          "/var/lib/crystal-forge"
          "/tmp"
          "/run/crystal-forge"
          "/var/cache/crystal-forge-nix"
        ];
      };
    };

    networking.firewall.allowedTCPPorts = [ cfg.server.port ];
    # ---- Vault Agent: render the files we consume above ----
    fmf.services.vault-agent.services."crystal-forge-setup" = {
      settings = {
        vault.address = cfg.vault-address;
        auto_auth.method = [{
          type = "approle";
          config = {
            role_id_file_path = cfg.role-id;
            secret_id_file_path = cfg.secret-id;
            remove_secret_id_file_after_reading = false;
          };
        }];
      };
      secrets.file.files = {
        # Agent private key (per-host key from KV)
        "agent.key" = {
          text = ''
            {{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ index .Data "${host}" }}{{ else }}{{ index .Data.data "${host}" }}{{ end }}{{ end }}
          '';
          permissions = "0600";
          change-action = "restart";
        };

        "builder.key" =
          lib.mkIf (cfg.build.enable && cfg.builder.enable_api_mode) {
            text = ''
              {{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ index .Data "${cfg.builder.private_key_vault_field}" }}{{ else }}{{ index .Data.data "${cfg.builder.private_key_vault_field}" }}{{ end }}{{ end }}
            '';
            permissions = "0600";
            change-action = "restart";
          };

        # Attic env (optional)
        "attic-env" = lib.mkIf
          (cfg.cache.cache_type == "Attic" && cfg.cache.push_to != null) {
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

        # S3 env + signing key (optional)
        "s3-env" =
          lib.mkIf (cfg.cache.cache_type == "S3" && cfg.cache.push_to != null) {
            text = ''
              AWS_ACCESS_KEY_ID={{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.minio_access_key }}{{ else }}{{ .Data.data.minio_access_key }}{{ end }}{{ end }}
              AWS_SECRET_ACCESS_KEY={{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.minio_secret_key }}{{ else }}{{ .Data.data.minio_secret_key }}{{ end }}{{ end }}
              ${lib.optionalString (cfg.cache.s3_region != null)
              "AWS_REGION=${cfg.cache.s3_region}"}
              AWS_EC2_METADATA_DISABLED=true
              HOME=/var/lib/crystal-forge
              XDG_CONFIG_HOME=/var/lib/crystal-forge/.config
            '';
            permissions = "0644";
            change-action = "restart";
          };

        "signing-key" =
          lib.mkIf (cfg.cache.cache_type == "S3" && cfg.cache.push_to != null) {
            text = ''
              {{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.signing_key }}{{ else }}{{ .Data.data.signing_key }}{{ end }}{{ end }}
            '';
            permissions = "0600";
            change-action = "restart";
          };

        "oidc-client-secret" = lib.mkIf
          (effectiveOidcEnabled && effectiveOidcClientSecretFile != null) {
            text = ''
              {{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ index .Data "${cfg.server.oidc.clientSecretVaultField}" }}{{ else }}{{ index .Data.data "${cfg.server.oidc.clientSecretVaultField}" }}{{ end }}{{ end }}
            '';
            permissions = "0600";
            change-action = "restart";
          };
      };
    };

    assertions = [
      {
        assertion = !cfg.authentik.enable || cfg.server.enable;
        message =
          "fmf.services.crystal-forge.authentik.enable requires crystal-forge.server.enable = true.";
      }
      {
        assertion = !cfg.authentik.enable || cfg.authentik.redirectUri != null;
        message =
          "fmf.services.crystal-forge.authentik.redirectUri must be set when Authentik support is enabled.";
      }
      {
        assertion = !cfg.authentik.enable || cfg.authentik.clientSecretFile
          != null;
        message =
          "fmf.services.crystal-forge.authentik.clientSecretFile must be set when Authentik support is enabled.";
      }
      {
        assertion = !cfg.builder.enable_api_mode
          || (cfg.builder.builder_id != null && cfg.builder.server_url != null);
        message =
          "fmf.services.crystal-forge.builder.enable_api_mode requires builder_id and server_url to be set.";
      }
    ];
  };
}
