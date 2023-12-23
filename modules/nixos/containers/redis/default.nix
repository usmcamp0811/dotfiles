inputs@{ options, config, lib, ... }:

with lib;
with lib.campground;
let
  cfg = config.campground.cli-apps.cowsay;
in
{
  options.campground.cli-apps.cowsay = with types; {
    enable = mkBoolOpt false "Whether or not to enable cowsay.";
  };

  config = mkIf cfg.enable {
    pkgs = import nixpkgs {
      overlays = [ nix-snapshotter.overlays.default ];
    };

    # Builds a native Nix image but intended for an OCI-compliant registry.
    redis = pkgs.nix-snapshotter.buildImage {
      name = "ghcr.io/pdtpartners/redis";
      tag = "latest";
      config.entrypoint = [ "${pkgs.redis}/bin/redis-server" ];
    };
  };
}


