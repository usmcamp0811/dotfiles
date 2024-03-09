{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
let
  cfg = config.campground.services.traefik;
in
{
  options.campground.services.traefik = with types; {
    enable = mkBoolOpt false "Enable an Tang;";
    port = mkOption {
      type = types.listOf  types.str;
      default = ["80" "443" ];
      description = "Port to Host the traefik server on.";
    };
  };

  config = mkIf cfg.enable {
    services.traefik = {
      enable = true;

      dynamicConfigOptions = {
        http.routers.simplehttp = {
          rule = "Host(`searx.campground.lan`)";
          entryPoints = [ "web" ];
          service = "simplehttp";
        };

        http.services.simplehttp = {
          loadBalancer.servers = [{
            url = "http://127.0.0.1:3249";
          }];
        };
      };

      staticConfigOptions = {
        global = {
          checkNewVersion = false;
          sendAnonymousUsage = false;
        };

        entryPoints.web.address = ":\${HTTP_PORT}";

        providers.docker.exposedByDefault = false;
      };
      environmentFiles = [(pkgs.writeText "traefik.env" ''
        HTTP_PORT=80
      '')];
    };
  };
}
