{ options, config, lib, inputs, ... }:
with lib;
with lib.campground;
let

  cfg = config.campground.suites.lan-hosting;

  generateServiceConfig = serviceName:
    let
      # Use the existing `lookupServiceEndpoint` function
      serviceEndpoints = lib.campground.lookupServiceEndpoint {
        nixosConfigurations = inputs.self.nixosConfigurations;
        serviceName = serviceName;
      };
    in
    { loadBalancer.servers = serviceEndpoints; };
  jsonValue = with types;
    let
      valueType = nullOr
        (oneOf [
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
    in
    valueType;
in
{
  options.campground.suites.lan-hosting = with types; {
    enable = mkBoolOpt false
      "Whether or not to enable common lan-hosting configuration.";
    interface = mkOpt str "eno1" "Interface to use for the LAN Instance";
    lan-ip = mkOpt str "10.8.0.69" "IP to use for the LAN Instance";
    entrypoints = mkOption {
      type = jsonValue;
      default = {
        web = { address = "0.0.0.0:80"; };
        metrics = { address = "0.0.0.0:58082"; };
      };
      example = { web = { address = "0.0.0.0:80"; }; };
      description =
        "List of entrypoints for Traefik, mapping names to their address.";
    };
  };

  config = {
    campground = {
      services = {
        prometheus.additionalScrapeConfigs = [{
          job_name = "lan-traefik-monitor";
          static_configs = [{ targets = [ "${cfg.lan-ip}:58082" ]; }];
        }];
        traefik = mkIf cfg.enable {
          enable = true;
          insecure = true;
          entrypoints =
            cfg.entrypoints; # // { dashboard = { address = "lucas:9090"; }; };
          dynamicConfigOptions = {
            # Define the IP whitelist middleware
            http.middlewares.ip-whitelist = {
              ipWhiteList = { sourceRange = [ "10.8.0.0/24" "172.16.0.0/8" ]; };
            };

            ############################################################################
            #                       AKHQ                                               #
            ############################################################################
            http.middlewares.akhq-auth = {
              forwardAuth = {
                address =
                  "https://auth.aicampground.com/outpost.goauthentik.io/auth/traefik";
                trustForwardHeader = true;
                authResponseHeaders = [
                  "X-authentik-username"
                  "X-authentik-groups"
                  "X-authentik-entitlements"
                  "X-authentik-email"
                  "X-authentik-name"
                  "X-authentik-uid"
                  "X-authentik-jwt"
                  "X-authentik-meta-jwks"
                  "X-authentik-meta-outpost"
                  "X-authentik-meta-provider"
                  "X-authentik-meta-app"
                  "X-authentik-meta-version"
                ];
              };
            };

            http.routers.akhq-auth = {
              rule =
                "Host(`akhq.lan.aicampground.com`) && PathPrefix(`/outpost.goauthentik.io/`)";
              priority = 15;
              service = "akhq-auth";
            };

            http.routers.akhq = {
              rule = "Host(`akhq.lan.aicampground.com`)";
              entryPoints = [ "websecure" ];
              service = "akhq";
              middlewares = [ "akhq-auth" "ip-whitelist" ];
            };

            http.services.akhq = generateServiceConfig "akhq";

            ############################################################################

            http.routers.authentik = {
              rule = "Host(`auth.lan.aicampground.com`)";
              entryPoints = [ "websecure" ];
              service = "authentik";
              middlewares = [ "ip-whitelist" ];
            };

            http.services.akhq-auth = {
              loadBalancer.servers =
                [{ url = "http://daly:9000/outpost.goauthentik.io"; }];
            };

            http.services.authentik = generateServiceConfig "authentik";

            http.routers.flake-forge = {
              rule = "Host(`flakeforge.lan.aicampground.com`)";
              entryPoints = [ "websecure" ];
              service = "flake-forge";
              middlewares = [ "ip-whitelist" ];
            };

            http.services.flake-forge = generateServiceConfig "flake-forge";

            http.routers.file-share = {
              rule = "Host(`files.lan.aicampground.com`)";
              entryPoints = [ "websecure" ];
              service = "file-share";
              middlewares = [ "ip-whitelist" ];
            };

            http.services.file-share = generateServiceConfig "file-share";

            http.routers.n8n = {
              rule = "Host(`n8n.lan.aicampground.com`)";
              entryPoints = [ "websecure" ];
              service = "n8n";
              middlewares = [ "ip-whitelist" ];
            };

            http.services.n8n = generateServiceConfig "n8n";

            http.routers.matomo = {
              rule = "Host(`matomo.lan.aicampground.com`)";
              entryPoints = [ "websecure" ];
              service = "matomo";
              middlewares = [ "ip-whitelist" ];
            };

            http.services.matomo = generateServiceConfig "matomo";

            # http.routers.plaid = {
            #   rule = "Host(`plaid.lan.aicampground.com`)";
            #   entryPoints = [ "websecure" ];
            #   service = "plaid";
            # };
            #
            # http.services.plaid = {
            #   loadBalancer.servers = [{ url = "http://reckless:3000"; }];
            # };

            http.routers.firefly = {
              rule = "Host(`firefly.lan.aicampground.com`)";
              entryPoints = [ "websecure" ];
              service = "firefly";
              middlewares = [ "ip-whitelist" ];
            };

            http.services.firefly = generateServiceConfig "firefly";

            http.routers.local-ai = {
              rule = "Host(`local-ai.lan.aicampground.com`)";
              entryPoints = [ "websecure" ];
              service = "local-ai";
              middlewares = [ "ip-whitelist" ];
            };

            http.services.local-ai = generateServiceConfig "local-ai";

            http.routers.open-webui = {
              rule = "Host(`chad.lan.aicampground.com`)";
              entryPoints = [ "websecure" ];
              service = "open-webui";
              middlewares = [ "ip-whitelist" ];
            };

            http.services.open-webui = generateServiceConfig "open-webui";

            http.routers.schema-registry = {
              rule = "Host(`schema-registry.lan.aicampground.com`)";
              entryPoints = [ "websecure" ];
              service = "schema-registry";
              middlewares = [ "ip-whitelist" ];
            };

            http.services.schema-registry =
              generateServiceConfig "schema-registry";

            http.routers.kafka = {
              rule = "Host(`kafka.lan.aicampground.com`)";
              entryPoints = [ "websecure" ];
              service = "kafka";
              middlewares = [ "ip-whitelist" ];
            };

            http.services.kafka = generateServiceConfig "kafka";

            http.routers.prometheus = {
              rule = "Host(`prometheus.lan.aicampground.com`)";
              entryPoints = [ "websecure" ];
              service = "prometheus";
              middlewares = [ "ip-whitelist" ];
            };

            http.services.prometheus = generateServiceConfig "prometheus";

            http.routers.grafana = {
              rule = "Host(`grafana.lan.aicampground.com`)";
              entryPoints = [ "websecure" ];
              service = "grafana";
              middlewares = [ "ip-whitelist" ];
            };

            http.services.grafana = generateServiceConfig "grafana";

            # http.routers.keycloak = {
            #   rule = "Host(`keycloak.lan.aicampground.com`)";
            #   entryPoints = [ "websecure" ];
            #   service = "keycloak";
            #   middlewares = [ "ip-whitelist" ];
            # };

            # http.services.keycloak = {
            #   loadBalancer.servers = [{ url = "http://ermy:43852"; }];
            # };
            # http.services.keycloak = generateServiceConfig "keycloak";

            http.routers.hydra = {
              rule = "Host(`hydra.lan.aicampground.com`)";
              entryPoints = [ "websecure" ];
              service = "hydra";
              middlewares = [ "ip-whitelist" ];
            };

            http.services.hydra = generateServiceConfig "hydra";

            http.routers.uptime-kuma = {
              rule = "Host(`uptime.lan.aicampground.com`)";
              entryPoints = [ "websecure" ];
              service = "uptime-kuma";
              middlewares = [ "ip-whitelist" ];
            };

            http.services.uptime-kuma = generateServiceConfig "uptime-kuma";

            http.routers.pub-traefik = {
              rule = "Host(`public-traefik.lan.aicampground.com`)";
              entryPoints = [ "websecure" ];
              service = "pub-traefik";
              middlewares = [ "ip-whitelist" ];
            };

            http.services.pub-traefik = {
              loadBalancer.servers = [{ url = "http://10.8.0.42:8080"; }];
            };

            http.routers.sonar = {
              rule = "Host(`sonar.lan.aicampground.com`)";
              entryPoints = [ "websecure" ];
              service = "sonar";
              middlewares = [ "ip-whitelist" ];
            };

            http.services.sonar = {
              loadBalancer.servers = [{ url = "http://chesty:8989"; }];
            };

            http.routers.reiverr = {
              rule = "Host(`reiverr.lan.aicampground.com`)";
              entryPoints = [ "websecure" ];
              service = "reiverr";
              middlewares = [ "ip-whitelist" ];
            };

            http.services.reiverr = {
              loadBalancer.servers = [{ url = "http://chesty:9494"; }];
            };

            http.routers.radar = {
              rule = "Host(`radar.lan.aicampground.com`)";
              entryPoints = [ "websecure" ];
              service = "radar";
              middlewares = [ "ip-whitelist" ];
            };

            http.services.radar = {
              loadBalancer.servers = [{ url = "http://chesty:7878"; }];
            };

            http.routers.prowlarr = {
              rule = "Host(`prowlarr.lan.aicampground.com`)";
              entryPoints = [ "websecure" ];
              service = "prowlarr";
              middlewares = [ "ip-whitelist" ];
            };

            http.services.prowlarr = {
              loadBalancer.servers = [{ url = "http://chesty:9696"; }];
            };

            http.routers.jacket = {
              rule = "Host(`jacket.lan.aicampground.com`)";
              entryPoints = [ "websecure" ];
              service = "jacket";
              middlewares = [ "ip-whitelist" ];
            };

            http.services.jacket = {
              loadBalancer.servers = [{ url = "http://chesty:9117"; }];
            };

            http.routers.deluge = {
              rule = "Host(`deluge.lan.aicampground.com`)";
              entryPoints = [ "websecure" ];
              service = "deluge";
              middlewares = [ "ip-whitelist" ];
            };

            http.services.deluge = {
              loadBalancer.servers = [{ url = "http://chesty:8112"; }];
            };

            http.routers.minio = {
              rule = "Host(`s3.lan.aicampground.com`)";
              entryPoints = [ "websecure" ];
              service = "minio";
              middlewares = [ "ip-whitelist" ];
            };

            # TODO: make this work with my function
            http.services.minio = {
              loadBalancer.servers = [{ url = "http://webb:9001"; }];

              # loadBalancer.servers = lib.campground.lookupServiceEndpoint {
              #   nixosConfigurations = inputs.self.nixosConfigurations;
              #   serviceName = "minio";
              # };
              loadBalancer.healthCheck = {
                path = "/health";
                interval = "10s";
                timeout = "5s";
              };
            };

            # TODO: make this work with my function
            http.routers.minio-api = {
              rule = "Host(`s3-api.lan.aicampground.com`)";
              entryPoints = [ "websecure" ];
              service = "minio-api";
              middlewares = [ "ip-whitelist" ];
            };

            http.services.minio-api = {
              loadBalancer.servers = [{ url = "http://webb:9000"; }];
            };

            http.routers.mlflow = {
              rule = "Host(`mlflow.lan.aicampground.com`)";
              entryPoints = [ "websecure" ];
              service = "mlflow";
              middlewares = [ "ip-whitelist" ];
            };

            http.services.mlflow = {
              loadBalancer.servers = [{ url = "http://webb:8000"; }];
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
              middlewares = [ "ip-whitelist" ];
            };

            http.services.vault = {
              loadBalancer.servers = lib.campground.lookupServiceEndpoint {
                nixosConfigurations = inputs.self.nixosConfigurations;
                serviceName = "vault";
              };
              # loadBalancer.servers = [
              #   { url = "http://daly:8200"; }
              #   { url = "http://ermy:8200"; }
              #   { url = "http://chesty:8200"; }
              #   { url = "http://webb:8200"; }
              # ];
              loadBalancer.healthCheck = {
                path = "/v1/sys/health";
                interval = "10s";
                timeout = "5s";
              };
            };

            http.routers.nixery = {
              rule = "Host(`nixery.lan.aicampground.com`)";
              entryPoints = [ "websecure" ];
              service = "nixery";
              middlewares = [ "ip-whitelist" ];
            };

            http.services.nixery = generateServiceConfig "nixery";

            http.routers.paperless = {
              rule = "Host(`docs.lan.aicampground.com`)";
              entryPoints = [ "websecure" ];
              service = "paperless";
              middlewares = [ "ip-whitelist" ];
            };
            http.services.paperless = generateServiceConfig "paperless";

            http.routers.jellyfin = {
              rule = "Host(`jellyfin.lan.aicampground.com`)";
              entryPoints = [ "websecure" ];
              service = "jellyfin";
            };

            http.services.jellyfin = {
              loadBalancer.servers = [{ url = "http://chesty:8096"; }];
              loadBalancer.healthCheck = {
                path = "/health";
                interval = "10s";
                timeout = "5s";
              };
            };
          };
        };

        keepalived = mkIf cfg.enable {
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
