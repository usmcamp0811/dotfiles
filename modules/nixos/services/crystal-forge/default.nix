{ config, lib, pkgs, ... }:

let
  agentVaultKeyPath = "/tmp/detsys-vault/${config.networking.hostName}.key";

  # Helper: accept any type (attrs, list, scalar) and forward to upstream.
  mkFwd = desc: lib.mkOption {
    type = lib.types.anything;
    default = {};
    description = "Forwarded to services.crystal-forge.${desc}";
  };
  mkFwdList = desc: lib.mkOption {
    type = lib.types.anything;
    default = [];
    description = "Forwarded to services.crystal-forge.${desc}";
  };
in {
  # ---------------------------------------------------------------------------
  # THIN WRAPPER AROUND THE UPSTREAM services.crystal-forge MODULE
  #
  # Snowfall's `namespace = "fmf"` makes host config attributes land under
  # `fmf.services.crystal-forge.*`.  This module defines forwarding stubs so
  # host configs can use that namespace, then sets services.crystal-forge.*
  # on the upstream module (imported in /config/flake.nix).
  #
  # All actual systemd services, slices, and Nix subprocess management come
  # from upstream.  Only vault-agent secret injection lives here, following
  # the same `secrets.environment.templates` pattern as other services
  # (navidrome, traefik, attic, grafana, etc.).
  # ---------------------------------------------------------------------------

  options.fmf.services.crystal-forge = {
    # ── Vault-specific options ────────────────────────────────────────────
    role-id = lib.mkOption {
      type = lib.types.str;
      default = "secret/detsys/role-id";
    };
    secret-id = lib.mkOption {
      type = lib.types.str;
      default = "secret/detsys/secret-id";
    };
    vault-path = lib.mkOption {
      type = lib.types.str;
      default = "secret/campground/crystal-forge/agents";
    };
    kvVersion = lib.mkOption {
      type = lib.types.str;
      default = "v2";
    };
    vault-address = lib.mkOption {
      type = lib.types.str;
      default = "https://vault.aicampground.com";
    };
    vault_path_cache = lib.mkOption {
      type = lib.types.str;
      default = "secret/campground/crystal-forge";
    };

    # ── Options forwarded to upstream services.crystal-forge.* ────────────
    enable = lib.mkEnableOption "Crystal Forge service(s)";
    log_level = lib.mkOption {
      type = lib.types.enum ["off" "error" "warn" "info" "debug" "trace"];
      default = "info";
    };
    server = mkFwd "server";
    build = mkFwd "build";
    cache = mkFwd "cache";
    database = mkFwd "database";
    deployment = mkFwd "deployment";
    local-database = lib.mkOption { type = lib.types.bool; default = false; };
    vulnix = mkFwd "vulnix";
    client = mkFwd "client";
    dashboards = mkFwd "dashboards";
    auth = mkFwd "auth";
    environments = mkFwdList "environments";
    systems = mkFwdList "systems";
    flakes = mkFwd "flakes";
    hardening = mkFwd "hardening";
  };

  # ── Forward fmf-namespace options + vault-agent integration ────────────
  config = let
    vCfg = config.fmf.services.crystal-forge;
  in lib.mkIf vCfg.enable {

    services.crystal-forge = {
      enable = true;
      log_level = vCfg.log_level;
      server = lib.mkDefault vCfg.server;
      build = lib.mkDefault vCfg.build;
      cache = lib.mkDefault vCfg.cache;
      database = lib.mkDefault vCfg.database;
      deployment = lib.mkDefault vCfg.deployment;
      local-database = lib.mkDefault vCfg.local-database;
      vulnix = lib.mkDefault vCfg.vulnix;
      # Provide default private_key path.  The common suite sets
      # client.enable = true but does not set private_key, relying on
      # vault-agent to render the key to agentVaultKeyPath.
      client = lib.mkIf (vCfg.client != {}) (lib.mkDefault
        (vCfg.client // {
          private_key = agentVaultKeyPath;
        }));
      dashboards = lib.mkDefault vCfg.dashboards;
      auth = lib.mkDefault vCfg.auth;
      environments = lib.mkDefault vCfg.environments;
      systems = lib.mkDefault vCfg.systems;
      flakes = lib.mkDefault vCfg.flakes;
      hardening = lib.mkDefault vCfg.hardening;
    };

    # ── Vault-agent: render cache encryption key for Attic push ───────────
    # Follows the same secrets.environment.templates pattern as navidrome,
    # traefik, attic, and other services in this flake.
    fmf.services.vault-agent.services."crystal-forge-server" = {
      settings = {
        vault.address = vCfg.vault-address;
        auto_auth = {
          method = [{
            type = "approle";
            config = {
              role_id_file_path = vCfg.role-id;
              secret_id_file_path = vCfg.secret-id;
              remove_secret_id_file_after_reading = false;
            };
          }];
        };
      };
      secrets.environment.templates = {
        "cache-encryption-key" = {
          text = ''
            {{ with secret "${vCfg.vault_path_cache}/cache-encryption-key" }}
            CRYSTAL_FORGE_CACHE_ENCRYPTION_KEY={{ if eq "${vCfg.kvVersion}" "v1" }}{{ .Data.value }}{{ else }}{{ .Data.data.value }}{{ end }}
            {{ end }}
          '';
        };
      };
    };

    # ── Vault-agent: agent private key (when client.enable) ───────────────
    fmf.services.vault-agent.services."crystal-forge-agent" = lib.mkIf
      (vCfg.client.enable or false) {
        settings = {
          vault.address = vCfg.vault-address;
          auto_auth = {
            method = [{
              type = "approle";
              config = {
                role_id_file_path = vCfg.role-id;
                secret_id_file_path = vCfg.secret-id;
                remove_secret_id_file_after_reading = false;
              };
            }];
          };
        };
        secrets.environment.templates."agent-key" = {
          text = ''
            {{ with secret "${vCfg.vault-path}/${config.networking.hostName}" }}
            CRYSTAL_FORGE_AGENT_PRIVATE_KEY={{ if eq "${vCfg.kvVersion}" "v1" }}{{ .Data.value }}{{ else }}{{ .Data.data.value }}{{ end }}
            {{ end }}
          '';
        };
      };

    # ── Attic client in server PATH ──────────────────────────────────────
    systemd.services.crystal-forge-server = {
      path = lib.mkAfter [ pkgs.attic-client ];
    };
  };
}
