{ options, config, lib, pkgs, ... }:

with lib;
with lib.campground;
let
  cfg = config.campground.suites.lan-hosting;
  jsonValue = with types;
    let
      valueType = nullOr (oneOf [
        bool
        int
        float
        str
        (lazyAttrsOf valueType)
        (listOf valueType)
      ]) // {
        description = "JSON value";
        emptyValue.value = { };
      };
    in valueType;
in
{
  options.campground.suites.lan-hosting = with types; {
    enable = mkBoolOpt false "Whether or not to enable common lan-hosting configuration.";
    interface = mkOpt str "eno1" "Interface to use for the LAN Instance";
    lan-ip = mkOpt str "10.8.0.69" "IP to use for the LAN Instance";
    entrypoints = mkOption {
      type = jsonValue;
      default = { web = { address = "0.0.0.0:80"; }; };
      example = { web = { address = "0.0.0.0:80"; }; };
      description = "List of entrypoints for Traefik, mapping names to their address.";
    };
  };

  config = mkIf cfg.enable {
    campground = {
      services = {
        traefik = {
          enable = true;
          insecure = true;
          entrypoints = cfg.entrypoints; # // { dashboard = { address = "lucas:9090"; }; };
          dynamicConfigOptions = {
            http.routers.minio = {
              rule = "Host(`s3.lan.aicampground.com`)";
              entryPoints = [ "websecure" ];
              service = "minio-api";
            };

            http.services.minio = {
              loadBalancer.servers = [
                { url = "http://webb:9001"; }
              ];
              loadBalancer.healthCheck = {
                path = "/health"; 
                interval = "10s"; 
                timeout = "5s";
              };
            };

            http.routers.minio-api = {
              rule = "Host(`s3-api.lan.aicampground.com`)";
              entryPoints = [ "websecure" ];
              service = "minio-api";
            };

            http.services.minio-api = {
              loadBalancer.servers = [
                { url = "http://webb:9000"; }
              ];
              loadBalancer.healthCheck = {
                path = "/health"; 
                interval = "10s"; 
                timeout = "5s";
              };
            };

            http.routers.mlflow = {
              rule = "Host(`mlflow.lan.aicampground.com`)";
              entryPoints = [ "websecure" ];
              service = "mlflow";
            };

            http.services.mlflow = {
              loadBalancer.servers = [
                { url = "http://webb:8000"; }
              ];
              loadBalancer.healthCheck = {
                path = "/health"; 
                interval = "10s"; 
                timeout = "5s";
              };
            };

            http.routers.vault = {
              rule = "Host(`vault.lan.aicampground.com`)";
              entryPoints = [ "websecure" ];
              service = "vault";
            };

            http.services.vault = {
              loadBalancer.servers = [
                { url = "http://daly:8200"; }
              ];
              loadBalancer.healthCheck = {
                path = "/health"; 
                interval = "10s"; 
                timeout = "5s";
              };
            };

            http.routers.nixery = {
              rule = "Host(`nixery.lan.aicampground.com`)";
              entryPoints = [ "websecure" ];
              service = "nixery";
            };

            http.services.nixery = {
              loadBalancer.servers = [
                { url = "http://webb:4567"; }
              ];
            };

            http.routers.paperless = {
              rule = "Host(`docs.lan.aicampground.com`)";
              entryPoints = [ "websecure" ];
              service = "paperless";
            };

            http.services.paperless = {
              loadBalancer.servers = [
                { url = "http://webb:28981"; }
              ];
            };

            http.routers.jellyfin = {
              rule = "Host(`jellyfin.lan.aicampground.com`)";
              entryPoints = [ "websecure" ];
              service = "jellyfin";
            };

            http.services.jellyfin = {
              loadBalancer.servers = [
                { url = "http://chesty:8096"; }
              ];
              loadBalancer.healthCheck = {
                path = "/health"; 
                interval = "10s"; 
                timeout = "5s";
              };
            };
          };
        };
        keepalived = {
          enable = true;
          instances = {
            "lan-campground" = {
              interface = cfg.interface;
              ips = [ cfg.lan-ip ];
              state = "MASTER";
              priority = 50;
              virtualRouterId = 52;
            };
          };
        };
      };
    };
  };
}
