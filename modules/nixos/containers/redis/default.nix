inputs@{ options, pkgs, config, lib, ... }:

with lib;
with lib.campground;
let
  cfg = config.campground.containers.redis;
in
{
  options.campground.containers.redis = with types; {
    enable = mkBoolOpt false "Whether or not to enable redis container.";
  };

  config = mkIf cfg.enable {
    # Builds a native Nix image but intended for an OCI-compliant registry.
    redis = pkgs.nix-snapshotter.buildImage {
      name = "redis";
      resolvedByNix = true;
      config.entrypoint = [ "${pkgs.redis}/bin/redis-server" ];
    };
  };
}


