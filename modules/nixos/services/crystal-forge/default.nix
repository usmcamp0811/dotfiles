{ config, lib, pkgs, ... }:

let
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
  # Snowfall namespace wrapper for the upstream services.crystal-forge module.
  # All services, slices, vault-agent injection come from upstream or
  # per-host config -- this only forwards option values to upstream.

  options.fmf.services.crystal-forge = {
    # ── Vault-specific options (used by crystal-forge-setup service) ──────
    vault_path_cache = lib.mkOption {
      type = lib.types.str;
      default = "secret/campground/crystal-forge";
      description = "Vault KV path for the Attic cache encryption key.";
    };
    kvVersion = lib.mkOption {
      type = lib.types.str;
      default = "v2";
      description = "Vault KV engine version (v1 or v2).";
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

  config = let
    vCfg = config.fmf.services.crystal-forge;
  in lib.mkIf vCfg.enable {
    services.crystal-forge = {
      inherit (vCfg) log_level;
      enable = true;
      server = lib.mkDefault vCfg.server;
      build = lib.mkDefault vCfg.build;
      cache = lib.mkDefault (vCfg.cache // {
        encryption_key_file = "/var/lib/crystal-forge/secrets/cache-encryption-key";
      });
      database = lib.mkDefault vCfg.database;
      deployment = lib.mkDefault vCfg.deployment;
      local-database = lib.mkDefault vCfg.local-database;
      vulnix = lib.mkDefault vCfg.vulnix;
      client = lib.mkDefault (vCfg.client // {
        private_key = "/var/lib/crystal-forge-agent/private.key";
      });
      dashboards = lib.mkDefault vCfg.dashboards;
      auth = lib.mkDefault vCfg.auth;
      environments = lib.mkDefault vCfg.environments;
      systems = lib.mkDefault vCfg.systems;
      flakes = lib.mkDefault vCfg.flakes;
      hardening = lib.mkDefault vCfg.hardening;
    };

    # ── Vault-agent: render cache encryption key as file ─────────────────
    # No settings block = inherits global fmf.services.vault-agent.settings
    # which has the correct role-id/secret-id paths per host.
    fmf.services.vault-agent.services."crystal-forge-setup" = lib.mkIf
      (config.fmf.services.vault-agent.enable or false) {
      secrets.file.files."cache-encryption-key" = {
        text = ''
          {{ with secret "${vCfg.vault_path_cache}" }}{{ if eq "${vCfg.kvVersion}" "v1" }}{{ .Data.value }}{{ else }}{{ .Data.data.value }}{{ end }}{{ end }}'';
        permissions = "0400";
        change-action = "restart";
      };
    };

    # ── Setup service: copy vault-rendered files to expected paths ────────
    systemd.services.crystal-forge-setup = lib.mkIf
      (config.fmf.services.vault-agent.enable or false) {
      description = "Copy vault-rendered Crystal Forge secrets to service paths";
      after = ["detsys-vaultAgent-crystal-forge-setup.service"];
      wants = ["detsys-vaultAgent-crystal-forge-setup.service"];
      before = ["crystal-forge-server.service" "crystal-forge-hardening.service"];
      wantedBy = ["crystal-forge-server.service" "crystal-forge-hardening.service"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = pkgs.writeShellScript "crystal-forge-setup" ''
          set -euo pipefail
          mkdir -p /var/lib/crystal-forge/secrets
          if [ -f /tmp/detsys-vault/cache-encryption-key ]; then
            cp /tmp/detsys-vault/cache-encryption-key /var/lib/crystal-forge/secrets/cache-encryption-key
            chown crystal-forge:crystal-forge /var/lib/crystal-forge/secrets/cache-encryption-key
            chmod 0400 /var/lib/crystal-forge/secrets/cache-encryption-key
            echo "cache encryption key: deployed"
          else
            echo "WARNING: /tmp/detsys-vault/cache-encryption-key not found"
            exit 1
          fi
          mkdir -p /var/lib/crystal-forge-agent
          if [ -f /tmp/detsys-vault/${config.networking.hostName}.key ]; then
            cp /tmp/detsys-vault/${config.networking.hostName}.key /var/lib/crystal-forge-agent/private.key
            chmod 0400 /var/lib/crystal-forge-agent/private.key
            echo "agent private key: deployed"
          fi
        '';
      };
    };

    # ── Attic client in server PATH ──────────────────────────────────────
    systemd.services.crystal-forge-server = {
      path = lib.mkAfter [ pkgs.attic-client ];
    };
  };
}
