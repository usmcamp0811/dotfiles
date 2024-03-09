{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
let
  cfg = config.campground.services.traefik;
  # toEntryPointsFormat = entrypoints: lib.foldl' (acc: ep: acc // {
  #   "${lib.head (lib.attrNames ep)}".address = lib.head (lib.attrValues ep);
  # }) {} entrypoints;
in
{
  options.campground.services.traefik = with types; {
    enable = mkBoolOpt false "Enable an Tang;";
    docker-provider = mkBoolOpt false "Whether or not to enable syncthing.";
    http = lib.mkOption {
      type = lib.types.attrs;
      default = {};
      description = "HTTP configuration for routers and services";
    };
    entrypoints = mkOption {
      type = types.attrsOf types.str;
      default = { web = "0.0.0.0:80"; };
      example = { web = "0.0.0.0:80"; };
      description = "List of entrypoints for Traefik, mapping names to their address.";
    };
  };

  config = mkIf cfg.enable {
    services.traefik = {
      enable = true;

      dynamicConfigOptions = {
        http = {
          routers = cfg.http.routers;
          services = cfg.http.services;
        };
      };
      staticConfigOptions = {
        global = {
          checkNewVersion = false;
          sendAnonymousUsage = false;
        };

        api = {
          dashboard = true;
          insecure = true; # Set to false in production and use proper authentication and HTTPS
        };
        entryPoints = mapAttrs' (name: address: {
          name = name;
          value = address;
        }) cfg.entrypoints;
        providers.docker.exposedByDefault = cfg.docker-provider;
      };
      # environmentFiles = [(pkgs.writeText "traefik.env" ''
      #   HTTP_PORT=80
      # '')];
    };
  };
}

