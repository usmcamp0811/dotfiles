{ options, config, lib, pkgs, ... }:

with lib;
with lib.campground;
let
  cfg = config.campground.suites.hosting;
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
  options.campground.suites.hosting = with types; {
    enable = mkBoolOpt false "Whether or not to enable common hosting configuration.";
    interface = mkOpt str "eno1" "Interface to use for the LAN Instance";
    lan-interface = mkOpt str cfg.interface "Interface to use for the LAN Instance";
    pub-interface = mkOpt str cfg.interface "Interface to use for the Public Instance";
    lan-ip = mkOpt str "10.8.0.69" "IP to use for the LAN Instance";
    pub-ip = mkOpt str "10.8.0.70" "IP to use for the Public Instance";
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
            http.routers.searx = {
              rule = "Host(`searx.aicampground.com`)";
              entryPoints = [ "web" ];
              service = "searx";
            };

            http.services.searx = {
              loadBalancer.servers = [
                { url = "http://webb:3249"; }
                { url = "http://daly:3249"; }
                { url = "http://chesty:3249"; }
                { url = "http://lucas:3249"; }
                { url = "http://reckless:3249"; }
              ];
            };

            http.routers.attic = {
              rule = "Host(`attic.aicampground.com`)";
              entryPoints = [ "web" ];
              service = "attic";
            };

            http.services.attic = {
              loadBalancer.servers = [
                { url = "http://reckless:8080"; }
              ];
            };

            http.routers.bitwarden = {
              rule = "Host(`bw.aicampground.com`)";
              entryPoints = [ "web" ];
              service = "bitwarden";
            };

            http.services.bitwarden = {
              loadBalancer.servers = [
                { url = "http://webb:9012"; }
              ];
            };

            http.routers.mattermost = {
              rule = "Host(`mattermost.lan.aicampground.com`)";
              entryPoints = [ "websecure" ];
              service = "mattermost";
            };

            http.routers.mm = {
              rule = "Host(`mm.aicampground.com`)";
              entryPoints = [ "web" ];
              service = "mattermost";
            };

            http.services.mattermost = {
              loadBalancer.servers = [
                { url = "http://webb:8065"; }
              ];
            };
          };
        };
        keepalived = {
          enable = true;
          instances = {
            "pub-campground" = {
              interface = cfg.pub-interface;
              ips = [ cfg.pub-ip ];
              state = "MASTER";
              priority = 50;
              virtualRouterId = 51;
            };
            "lan-campground" = {
              interface = cfg.lan-interface;
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
