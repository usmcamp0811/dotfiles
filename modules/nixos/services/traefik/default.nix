{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
let
  cfg = config.campground.services.traefik;
in
{
  options.campground.services.traefik = with types; {
    enable = mkBoolOpt false "Enable an Tang;";
    docker-provider = mkBoolOpt false "Whether or not to enable syncthing.";
    insecure = mkBoolOpt false "Insecure dashboard?";
    dynamicConfigOptions = lib.mkOption {
      type = lib.types.attrs;
      default = {};
      description = "HTTP configuration for routers and services";
    };
    entrypoints = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          address = mkOption {
            type = types.str;
            default = "0.0.0.0:80";
            example = "0.0.0.0:80";
            description = "Address to bind the entrypoint to";
          };
        };
      });
      default = { web = { address = "0.0.0.0:80"; }; };
      example = { web = { address = "0.0.0.0:80"; }; };
      description = "List of entrypoints for Traefik, mapping names to their address.";
    };
  };

  config = mkIf cfg.enable {
    services.traefik = {
      enable = true;
      dynamicConfigOptions = cfg.dynamicConfigOptions;
      staticConfigOptions = {
        global = {
          checkNewVersion = false;
          sendAnonymousUsage = false;
        };

        api = {
          dashboard = true;
          insecure = cfg.insecure; # Set to false in production and use proper authentication and HTTPS
        };

        entryPoints = cfg.entrypoints;
        providers.docker.exposedByDefault = cfg.docker-provider;
      };
    };
  };
}

