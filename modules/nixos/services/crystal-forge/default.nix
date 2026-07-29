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
  };
}
