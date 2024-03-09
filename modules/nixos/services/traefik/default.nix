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
    http = lib.mkOption {
      type = lib.types.attrs;
      default = {};
      description = "HTTP configuration for routers and services";
    };
    entrypoints = lib.mkOption {
      type = lib.types.listOf (lib.types.attrsOf lib.types.str);
      default = [{ web = ":80" }];
      example = [{ web = ":80" }];
      description = "List of entrypoints for Traefik.";
    };
  };

  config = mkIf cfg.enable {
    services.traefik = {
      enable = true;

      dynamicConfigOptions = {
        http = {
          routers = cfg.http.routers;
          services = lib.mapAttrs (_: service: {
            loadBalancer = {
              servers = [{
                url = service.url;
              }];
            };
          }) cfg.http.services;
        };
      };

      staticConfigOptions = {
        global = {
          checkNewVersion = false;
          sendAnonymousUsage = false;
        };

        entryPoints = lib.foldl' (acc: ep: acc // lib.mapAttrsToList (name: value: { inherit name value; }) ep) {} cfg.entrypoints;
        providers.docker.exposedByDefault = cfg.docker-provider;
      };
      # environmentFiles = [(pkgs.writeText "traefik.env" ''
      #   HTTP_PORT=80
      # '')];
    };
  };
}

