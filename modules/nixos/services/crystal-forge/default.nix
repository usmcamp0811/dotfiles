{ config, lib, pkgs, ... }:

let
  # Vault-agent injects the agent private key here when enabled.
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
  # `fmf.services.crystal-forge.*`.  This module defines those namespace
  # options with generic types and forwards each value to the upstream
  # `services.crystal-forge.*` (imported in /config/flake.nix).
  #
  # The actual systemd services, slices, Nix subprocess management, and
  # resource limits all come from the upstream module.  Only deployment-
  # specific overrides live here.
  #
  # TO ADD VAULT-AGENT SECRET INJECTION: set path and text/template on
  # fmf.services.vault-agent.services."crystal-forge-server".secrets.*
  # See the vault-agent README at:
  #   modules/nixos/services/vault-agent/README.md
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

  # ── Forward fmf-namespace options to upstream services ──────────────────
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
      client = lib.mkDefault (vCfg.client // {
        private_key = agentVaultKeyPath;
      });
      dashboards = lib.mkDefault vCfg.dashboards;
      auth = lib.mkDefault vCfg.auth;
      environments = lib.mkDefault vCfg.environments;
      systems = lib.mkDefault vCfg.systems;
      flakes = lib.mkDefault vCfg.flakes;
      hardening = lib.mkDefault vCfg.hardening;
    };

    # ── Attic client in server PATH (needed for cache push credential deliv.) ─
    systemd.services.crystal-forge-server = {
      path = lib.mkAfter [ pkgs.attic-client ];
    };

    # ── vault-agent secret injection guide (uncomment and adjust paths) ─────
    # fmf.services.vault-agent.services."crystal-forge-server" = {
    #   secrets.environment.templates."cache-encryption-key" = {
    #     text = ''{{ with secret "${vCfg.vault_path_cache}/cache-encryption-key" }}{{ .Data.data.value }}{{ end }}'';
    #     path = "/var/lib/crystal-forge/secrets/cache-encryption-key";
    #   };
    # };
  };
}
