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
  # crystal-forge's own unit test asserts that the `nix` on its PATH is exactly
  # 2.34.8: the nix in *its* flake's nixpkgs pin. Its packaging deliberately uses
  # whatever Nix the consuming nixpkgs provides (`pkgs.nix-eval-jobs.nix`, see its
  # overlays/default), so built against fmf's nixpkgs that is whatever the channel
  # ships (2.34.9 after the Oct 21 unstable bump) and the build fails in
  # checkPhase although nothing is wrong with the code. crystal-forge's own CI
  # still runs the test against its pin; every other test still runs here.
  # Drop this once the test stops hard-coding a patch release.
  pinnedNixTest = "handlers::api::builders::tests::niks3_pinned_nix_accepts_remote_metadata_and_refresh_flags";
  # crane renders the cargo command into `checkPhase` when the package is
  # defined, so changing `cargoTestExtraArgs` afterwards has no effect: the
  # command itself is edited. The assertion turns a future change to that command
  # into a clear evaluation error instead of a silently ignored override.
  testArgs = "--lib --bins";
  serverPackage = pkgs.crystal-forge.default.cf-server-drv.overrideAttrs (old:
    assert lib.assertMsg (lib.hasInfix testArgs old.checkPhase)
    "crystal-forge's cf-server checkPhase no longer ends in `${testArgs}`; update the pinned-nix test skip in fmf's services/crystal-forge module."; {
      checkPhase = lib.replaceStrings [testArgs] ["${testArgs} -- --skip ${pinnedNixTest}"] old.checkPhase;
    });
in {
  # Snowfall namespace wrapper for the upstream services.crystal-forge module.
  # All services, slices, vault-agent injection come from upstream or
  # per-host config -- this only forwards option values to upstream.

  options.fmf.services.crystal-forge = {
    # ── Vault options (used by the cache-encryption-key template below) ───
    vault_path_cache = lib.mkOption {
      type = lib.types.str;
      default = "secret/campground/crystal-forge";
      description = "Vault KV path whose `value` field is the Attic cache encryption key.";
    };
    kvVersion = lib.mkOption {
      type = lib.types.enum ["v1" "v2"];
      default = "v2";
      description = "Vault KV engine version of `vault_path_cache`.";
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
      server = lib.mkDefault (lib.recursiveUpdate {
        trust_forwarded_builder_https = true;
        package = serverPackage;
      } vCfg.server);
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

    # ── Vault Agent: render the cache encryption key ─────────────────────
    # This template was removed on 2026-07-28 (1e1920aa8) and not replaced, so the setup service
    # below only worked while a file left behind in /tmp/detsys-vault survived; it broke the
    # first time /tmp was cleared.
    #
    # `settings` is required. A per-service agent does NOT inherit the host's global
    # fmf.services.vault-agent.settings: without it the generated agent config has an empty
    # auto_auth and no vault address, and the agent exits 1 straight away (this is what broke the
    # first attempt, the day before it was removed). Every other service passes its own, built from
    # the same three values (see services/crowdsec, cache/niks3).
    fmf.services.vault-agent.services."crystal-forge-setup" = lib.mkIf
      (config.fmf.services.vault-agent.enable or false) {
      settings = let
        vault = config.fmf.services.vault-agent.settings.vault;
      in {
        vault.address = vault.address;
        auto_auth.method = [
          {
            type = "approle";
            config = {
              role_id_file_path = vault."role-id";
              secret_id_file_path = vault."secret-id";
              remove_secret_id_file_after_reading = false;
            };
          }
        ];
      };
      secrets.file.files."cache-encryption-key" = {
        text = ''
          {{ with secret "${vCfg.vault_path_cache}" }}{{ if eq "${vCfg.kvVersion}" "v1" }}{{ .Data.value }}{{ else }}{{ .Data.data.value }}{{ end }}{{ end }}'';
        permissions = "0400";
        change-action = "restart";
      };
    };

    # ── Setup service: copy vault-rendered files to expected paths ────────
    # Ordered after the Vault Agent instance above, which renders the key into /tmp/detsys-vault/.
    systemd.services.crystal-forge-setup = lib.mkIf
      (config.fmf.services.vault-agent.enable or false) {
      description = "Copy vault-rendered Crystal Forge secrets to service paths";
      after = ["detsys-vaultAgent-crystal-forge-setup.service" "postgresql.service" "network-online.target"];
      # `after` only orders; without `wants` nothing pulls a unit in. network-online.target is here
      # because NixOS warns about ordering after it without depending on it.
      wants = ["detsys-vaultAgent-crystal-forge-setup.service" "network-online.target"];
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
