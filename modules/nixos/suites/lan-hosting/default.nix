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
            http.routers.authentik = {
              rule = "Host(`authentik.lan.aicampground.com`)";
              entryPoints = [ "websecure" ];
              service = "authentik";
            };

            http.services.authentik = generateServiceConfig "authentik";

            http.routers.flake-forge = {
              rule = "Host(`flakeforge.lan.aicampground.com`)";
              entryPoints = [ "websecure" ];
              service = "flake-forge";
            };

            http.services.flake-forge = generateServiceConfig "flake-forge";

            http.routers.file-share = {
              rule = "Host(`files.lan.aicampground.com`)";
              entryPoints = [ "websecure" ];
              service = "file-share";
            };

            http.services.file-share = generateServiceConfig "file-share";

            http.routers.n8n = {
              rule = "Host(`n8n.lan.aicampground.com`)";
              entryPoints = [ "websecure" ];
              service = "n8n";
            };

            http.services.n8n = generateServiceConfig "n8n";

            http.routers.matomo = {
              rule = "Host(`matomo.lan.aicampground.com`)";
              entryPoints = [ "websecure" ];
              service = "matomo";
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
            };

            http.services.firefly = generateServiceConfig "firefly";

            http.routers.local-ai = {
              rule = "Host(`local-ai.lan.aicampground.com`)";
              entryPoints = [ "websecure" ];
              service = "local-ai";
            };

            http.services.local-ai = generateServiceConfig "local-ai";

            http.routers.open-webui = {
              rule = "Host(`chad.lan.aicampground.com`)";
              entryPoints = [ "websecure" ];
              service = "open-webui";
            };

            http.services.open-webui = generateServiceConfig "open-webui";

            http.routers.schema-registry = {
              rule = "Host(`schema-registry.lan.aicampground.com`)";
              entryPoints = [ "websecure" ];
              service = "schema-registry";
            };

            http.services.schema-registry =
              generateServiceConfig "schema-registry";

            http.routers.akhq = {
              rule = "Host(`akhq.lan.aicampground.com`)";
              entryPoints = [ "websecure" ];
              service = "akhq";
            };

            http.services.akhq = generateServiceConfig "akhq";

            http.routers.kafka = {
              rule = "Host(`kafka.lan.aicampground.com`)";
              entryPoints = [ "websecure" ];
              service = "kafka";
            };

            http.services.kafka = generateServiceConfig "kafka";

            http.routers.prometheus = {
              rule = "Host(`prometheus.lan.aicampground.com`)";
              entryPoints = [ "websecure" ];
              service = "prometheus";
            };

            http.services.prometheus = generateServiceConfig "prometheus";

            http.routers.grafana = {
              rule = "Host(`grafana.lan.aicampground.com`)";
              entryPoints = [ "websecure" ];
              service = "grafana";
            };

            http.services.grafana = generateServiceConfig "grafana";

            http.routers.keycloak = {
              rule = "Host(`keycloak.lan.aicampground.com`)";
              entryPoints = [ "websecure" ];
              service = "keycloak";
            };

            # http.services.keycloak = {
            #   loadBalancer.servers = [{ url = "http://ermy:43852"; }];
            # };
            http.services.keycloak = generateServiceConfig "keycloak";

            http.routers.hydra = {
              rule = "Host(`hydra.lan.aicampground.com`)";
              entryPoints = [ "websecure" ];
              service = "hydra";
            };

            http.services.hydra = generateServiceConfig "hydra";

            http.routers.uptime-kuma = {
              rule = "Host(`uptime.lan.aicampground.com`)";
              entryPoints = [ "websecure" ];
              service = "uptime-kuma";
            };

            http.services.uptime-kuma = generateServiceConfig "uptime-kuma";

            http.routers.pub-traefik = {
              rule = "Host(`public-traefik.lan.aicampground.com`)";
              entryPoints = [ "websecure" ];
              service = "pub-traefik";
            };

            http.services.pub-traefik = {
              loadBalancer.servers = [{ url = "http://10.8.0.42:8080"; }];
            };

            http.routers.sonar = {
              rule = "Host(`sonar.lan.aicampground.com`)";
              entryPoints = [ "websecure" ];
              service = "sonar";
            };

            http.services.sonar = {
              loadBalancer.servers = [{ url = "http://chesty:8989"; }];
            };

            http.routers.reiverr = {
              rule = "Host(`reiverr.lan.aicampground.com`)";
              entryPoints = [ "websecure" ];
              service = "reiverr";
            };

            http.services.reiverr = {
              loadBalancer.servers = [{ url = "http://chesty:9494"; }];
            };

            http.routers.radar = {
              rule = "Host(`radar.lan.aicampground.com`)";
              entryPoints = [ "websecure" ];
              service = "radar";
            };

            http.services.radar = {
              loadBalancer.servers = [{ url = "http://chesty:7878"; }];
            };

            http.routers.prowlarr = {
              rule = "Host(`prowlarr.lan.aicampground.com`)";
              entryPoints = [ "websecure" ];
              service = "prowlarr";
            };

            http.services.prowlarr = {
              loadBalancer.servers = [{ url = "http://chesty:9696"; }];
            };

            http.routers.jacket = {
              rule = "Host(`jacket.lan.aicampground.com`)";
              entryPoints = [ "websecure" ];
              service = "jacket";
            };

            http.services.jacket = {
              loadBalancer.servers = [{ url = "http://chesty:9117"; }];
            };

            http.routers.deluge = {
              rule = "Host(`deluge.lan.aicampground.com`)";
              entryPoints = [ "websecure" ];
              service = "deluge";
            };

            http.services.deluge = {
              loadBalancer.servers = [{ url = "http://chesty:8112"; }];
            };

            http.routers.minio = {
              rule = "Host(`s3.lan.aicampground.com`)";
              entryPoints = [ "websecure" ];
              service = "minio";
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
            };

            http.services.minio-api = {
              loadBalancer.servers = [{ url = "http://webb:9000"; }];
            };

            http.routers.mlflow = {
              rule = "Host(`mlflow.lan.aicampground.com`)";
              entryPoints = [ "websecure" ];
              service = "mlflow";
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
            };

            http.services.nixery = generateServiceConfig "nixery";

            http.routers.paperless = {
              rule = "Host(`docs.lan.aicampground.com`)";
              entryPoints = [ "websecure" ];
              service = "paperless";
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
