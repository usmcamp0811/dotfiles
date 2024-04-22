{ lib, config, ... }:
with lib;
with lib.campground;
let
  cfg = config.campground.services.traefik;
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
  options.campground.services.traefik = with types; {
    enable = mkBoolOpt false "Enable an Tang;";
    email = mkOpt str config.campground.user.email "The email to use.";
    docker-provider = mkBoolOpt false "Whether or not to enable syncthing.";
    domains = mkOption {
      type = listOf str;
      default = [ "aicampground.com" ];
      example = [ "example.com" "example.org" ];
      description = "List of domains.";
    };
    log-path = mkOpt str "/var/lib/traefik/access.log"
      "The location to store the access log.";
    insecure = mkBoolOpt false "Insecure dashboard?";
    dynamicConfigOptions = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "HTTP configuration for routers and services";
    };
    entrypoints = mkOption {
      type = jsonValue;
      default = { web = { address = "0.0.0.0:80"; }; };
      example = { web = { address = "0.0.0.0:80"; }; };
      description =
        "List of entrypoints for Traefik, mapping names to their address.";
    };
    role-id =
      mkOpt str config.campground.services.vault-agent.settings.vault.role-id
      "Absolute path to the Vault role-id";
    secret-id =
      mkOpt str config.campground.services.vault-agent.settings.vault.secret-id
      "Absolute path to the Vault secret-id";
    vault-path = mkOpt str "secret/campground/cloudflare"
      "The Vault path to the KV containing the KVs that are for each database";
    kvVersion = mkOption {
      type = enum [ "v1" "v2" ];
      default = "v2";
      description = "KV store version";
    };
    vault-address = mkOption {
      type = str;
      default = config.campground.services.vault-agent.settings.vault.address;
      description = "The address of your Vault";
    };
  };

  config = mkIf cfg.enable {
    users.users.traefik = { extraGroups = [ "docker" ]; };
    systemd.services.traefik.serviceConfig.WorkingDirectory =
      "${config.services.traefik.package}/bin";
    services.traefik = {
      enable = true;
      dynamicConfigOptions = cfg.dynamicConfigOptions;
      staticConfigOptions = {

        experimental.localPlugins = {
          # fail2ban.moduleName = "github.com/tomMoulard/fail2ban";
          cloudflarewarp.moduleName = "github.com/BilikoX/cloudflarewarp";
        };
        global = {
          checkNewVersion = false;
          sendAnonymousUsage = false;
        };

        log = {
          level = "INFO";
          format = "json";
        };

        accessLog = {
          filePath = cfg.log-path;
          format = "json";
        };

        entryPoints = {
          web = {
            http.redirections.entryPoint = {
              to = "websecure";
              scheme = "https";
            };
          };
          websecure = {
            address = "0.0.0.0:443";
            http.tls = {
              certResolver = "cloudflare";
              domains = map (domain: {
                main = domain;
                sans = [ "*.${domain}" "*.lan.${domain}" ];
              }) cfg.domains;
            };
          };
        } // cfg.entrypoints;

        api = {
          dashboard = true;
          insecure = cfg.insecure;
        };
        certificatesResolvers = {
          cloudflare = {
            acme = {
              email = cfg.email;
              storage = "/var/lib/traefik/acme.json";
              dnsChallenge = {
                provider = "cloudflare";
                resolvers = [ "1.1.1.1:53" "1.0.0.1:53" ];
              };
            };
          };
        };
        providers.docker.exposedByDefault = cfg.docker-provider;
      };
    };
    campground = {
      services = {
        vault-agent = {
          services = {
            "traefik" = {
              settings = {
                vault.address = cfg.vault-address;
                auto_auth = {
                  method = [{
                    type = "approle";
                    config = {
                      role_id_file_path = cfg.role-id;
                      secret_id_file_path = cfg.secret-id;
                      remove_secret_id_file_after_reading = false;
                    };
                  }];
                };
              };
              secrets.environment.templates = {
                traefik = {
                  text = ''
                    {{ with secret "${cfg.vault-path}" }}
                    CF_DNS_API_TOKEN='{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.CLOUDFLARE_API_KEY }}{{ else }}{{ .Data.data.CLOUDFLARE_API_KEY }}{{ end }}'
                    CLOUDFLARE_DNS_API_TOKEN='{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.CLOUDFLARE_API_KEY }}{{ else }}{{ .Data.data.CLOUDFLARE_API_KEY }}{{ end }}'
                    {{ end }}
                  '';
                };
              };
            };
          };
        };
      };
    };
  };
}
# CLOUDFLARE_API_KEY='{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.CLOUDFLARE_API_KEY }}{{ else }}{{ .Data.data.CLOUDFLARE_API_KEY }}{{ end }}'
# CLOUDFLARE_EMAIL='{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.CLOUDFLARE_EMAIL }}{{ else }}{{ .Data.data.CLOUDFLARE_EMAIL }}{{ end }}'
# CF_API_EMAIL='{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.CLOUDFLARE_EMAIL }}{{ else }}{{ .Data.data.CLOUDFLARE_EMAIL }}{{ end }}'
# CF_API_KEY='{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.CLOUDFLARE_API_KEY }}{{ else }}{{ .Data.data.CLOUDFLARE_API_KEY }}{{ end }}'

