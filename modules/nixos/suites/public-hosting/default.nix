{ options, config, lib, ... }:
with lib;
with lib.campground;
let
  cfg = config.campground.suites.public-hosting;
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
in {
  options.campground.suites.public-hosting = with types; {
    enable = mkBoolOpt false
      "Whether or not to enable common public-hosting configuration.";
    interface = mkOpt str "eno1" "Interface to use for the LAN Instance";
    pub-ip = mkOpt str "10.8.0.42" "IP to use for the Public Instance";
    log-to-kafka =
      mkBoolOpt false "Enables the Traefik log Kafka Producer service";
    entrypoints = mkOption {
      type = jsonValue;
      default = { web = { address = "0.0.0.0:80"; }; };
      example = { web = { address = "0.0.0.0:80"; }; };
      description =
        "List of entrypoints for Traefik, mapping names to their address.";
    };
  };

  config = mkIf cfg.enable {
    campground = {
      kafka-producers = { traefik-logs = { enable = cfg.log-to-kafka; }; };
      services = {
        searx = {
          enable = true;
          port = 3249;
        };
        traefik = {
          enable = true;
          insecure = true;
          entrypoints = cfg.entrypoints;
          domains = [ "aicampground.com" "matt-camp.com" ];
          dynamicConfigOptions = {
            https.middlewares.cloudflarewarp = {
              plugin = { cloudflarewarp = { trustip = [ "1.1.1.1/24" ]; }; };
            };

            # http.routers.adhoc = {
            #   rule = "Host(`adhoc.aicampground.com`)";
            #   entryPoints = [ "websecure" ];
            #   service = "adhoc";
            # };
            #
            # http.services.adhoc = {
            #   loadBalancer.servers = [{ url = "http://reckless:5000"; }];
            # };

            http.routers.aicampground = {
              rule = "Host(`aicampground.com`) || Host(`matt-camp.com`)";
              entryPoints = [ "websecure" ];
              service = "aicampground";
            };

            # http.routers.matt-camp = {
            #   rule = "Host(`matt-camp.com`)";
            #   entryPoints = [ "websecure" ];
            #   service = "matt-camp";
            # };

            http.services.matt-camp = {
              loadBalancer.servers = [{ url = "http://lucas:4356"; }];
            };

            http.services.aicampground = {
              loadBalancer.servers = [{ url = "http://lucas:4356"; }];
            };

            http.routers.searx = {
              rule = "Host(`searx.aicampground.com`)";
              entryPoints = [ "websecure" ];
              service = "searx";
            };

            http.services.searx = {
              loadBalancer.servers = [
                { url = "http://webb:3249"; }
                { url = "http://daly:8181"; }
                { url = "http://chesty:3249"; }
                { url = "http://lucas:3249"; }
                { url = "http://reckless:3249"; }
              ];

              loadBalancer.healthCheck = {
                path = "/";
                interval = "10s";
                timeout = "5s";
              };
            };

            http.routers.photoprism = {
              rule = "Host(`photos.aicampground.com`)";
              entryPoints = [ "websecure" ];
              service = "photoprism";
              middlewares = [ "cloudflarewarp" ];
            };

            http.services.photoprism = {
              loadBalancer.servers = [{ url = "http://webb:9080"; }];
            };

            http.routers.attic = {
              rule = "Host(`attic.aicampground.com`)";
              entryPoints = [ "websecure" ];
              service = "attic";
            };

            http.services.attic = {
              loadBalancer.servers = [{ url = "http://reckless:8082"; }];
            };

            http.routers.bitwarden = {
              rule = "Host(`bw.aicampground.com`)";
              entryPoints = [ "websecure" ];
              service = "bitwarden";
            };

            http.services.bitwarden = {
              loadBalancer.servers = [{ url = "http://webb:8989"; }];
              loadBalancer.healthCheck = {
                path = "/alive";
                interval = "10s";
                timeout = "5s";
              };
            };

            http.routers.mattermost = {
              rule = "Host(`mattermost.aicampground.com`)";
              entryPoints = [ "websecure" ];
              service = "mattermost";
            };

            http.routers.mm = {
              rule = "Host(`mm.aicampground.com`)";
              entryPoints = [ "websecure" ];
              service = "mattermost";
            };

            http.services.mattermost = {
              loadBalancer.servers = [{ url = "http://webb:8065"; }];
            };
          };
        };
        keepalived = {
          enable = true;
          instances = {
            "pub-campground" = {
              interface = cfg.interface;
              ips = [ cfg.pub-ip ];
              state = "MASTER";
              priority = 50;
              virtualRouterId = 51;
            };
          };
        };
      };
    };
  };
}
