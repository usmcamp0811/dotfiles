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

    # ── Setup service: copy vault-rendered files to expected paths ────────
    # Relies on the globally-configured fmf.services.vault-agent having already
    # rendered secrets to /tmp/detsys-vault/.  Does NOT create its own vault-
    # agent instance because the global vault-agent config format conflicts
    # with per-service settings inheritance.
    systemd.services.crystal-forge-setup = lib.mkIf
      (config.fmf.services.vault-agent.enable or false) {
      description = "Copy vault-rendered Crystal Forge secrets to service paths";
      after = ["postgresql.service" "network-online.target"];
      # `after` only orders; without `wants` nothing pulls the target in, which is
      # what NixOS warns about ("ordered after network-online.target but doesn't
      # depend on it").
      wants = ["network-online.target"];
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
