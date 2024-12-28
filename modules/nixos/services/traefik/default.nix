{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
let
  cfg = config.campground.services.traefik;
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
  saveCert2Vault = pkgs.writeShellScriptBin "save-certs" ''
    ACME_JSON="${cfg.acme-path}"
    # Vault base path
    VAULT_BASE_PATH="${cfg.vault-path}"

    ROLE_ID=$(cat "${cfg.role-id}")
    SECRET_ID=$(cat "${cfg.secret-id}")
    VAULT_TOKEN=$(${pkgs.curl}/bin/curl -s --request POST --data '{"role_id":"'$ROLE_ID'","secret_id":"'$SECRET_ID'"}' "$VAULT_ADDR/v1/auth/approle/login" | jq -r '.auth.client_token')

      # Check if acme.json exists
    if [[ ! -f "$ACME_JSON" ]]; then
        echo "Error: $ACME_JSON not found."
        exit 1
    fi
    # Parse acme.json and extract certificates and keys
    certificates=$(jq -c '.cloudflare.Certificates[]' "$ACME_JSON")
    if [[ -z "$certificates" ]]; then
        echo "Error: No certificates found in $ACME_JSON."
        exit 1
    fi
    # Loop through each certificate entry
    while IFS= read -r cert_entry; do
        domain=$(echo "$cert_entry" | jq -r '.domain.main')
        cert=$(echo "$cert_entry" | jq -r '.certificate')
        key=$(echo "$cert_entry" | jq -r '.key')

        if [[ -z "$domain" || -z "$cert" || -z "$key" ]]; then
            echo "Warning: Incomplete data for a certificate, skipping."
            continue
        fi

        # Vault path for the domain
        vault_path="$VAULT_BASE_PATH/$domain"
        echo "Saving certificate for $domain to Vault at $vault_path..."

        # Store in Vault using CLI
        echo "$cert" > cert.pem
        echo "$key" > key.pem 
        ${pkgs.vault-bin}/bin/vault kv put "$vault_path" cert=@cert.pem key=@key.pem

        if [[ $? -ne 0 ]]; then
            echo "Error: Failed to save certificate for $domain."
        else
            echo "Certificate for $domain saved successfully."
        fi

        # Cleanup temporary files
        rm -f cert.pem key.pem

    done <<< "$certificates"
    echo "All certificates processed." 
  '';
in
{
  options.campground.services.traefik = with types; {
    enable = mkBoolOpt false "Enable an Tang;";
    email = mkOpt str config.campground.user.email "The email to use.";
    docker-provider = mkBoolOpt false "Whether or not to enable syncthing.";
    acme-path = mkOpt str "/var/lib/traefik/acme.json"
      "The location Traefik saves the certs";
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

    systemd.services.saveCertsToVault = {
      description = "Save TLS Certs in Vault";
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        WorkingDirectory = "/var/lib/traefik";
        ReadWritePaths = [ "/var/lib/traefik" ];
      };
      script = ''
        while [[ ! -f ${cfg.acme-path} ]]; do sleep 1; done && ${saveCert2Vault}/bin/save-certs
      '';
      wantedBy = [ "multi-user.target" ];
      after = [ "traefik.service" ];
    };

    users.users.traefik = { extraGroups = [ "docker" ]; };
    systemd.services.traefik.serviceConfig.WorkingDirectory =
      "${config.services.traefik.package}/bin";
    services.traefik = {
      enable = true;
      dynamicConfigOptions = cfg.dynamicConfigOptions;
      staticConfigOptions = {

        experimental.localPlugins = {
          cloudflarewarp.moduleName = "github.com/BilikoX/cloudflarewarp";
          fail2ban.moduleName = "github.com/tomMoulard/fail2ban";
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
            forwardedHeaders = {
              trustedIPs = [
                "173.245.48.0/20"
                "103.21.244.0/22"
                "103.22.200.0/22"
                "103.31.4.0/22"
                "141.101.64.0/18"
                "108.162.192.0/18"
                "190.93.240.0/20"
                "188.114.96.0/20"
                "197.234.240.0/22"
                "198.41.128.0/17"
                "162.158.0.0/15"
                "104.16.0.0/13"
                "104.24.0.0/14"
                "172.64.0.0/13"
                "131.0.72.0/22"
              ];
            };
            http.tls = {
              certResolver = "cloudflare";
              domains = map
                (domain: {
                  main = domain;
                  sans = [ "*.${domain}" "*.lan.${domain}" ];
                })
                cfg.domains;
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
              storage = "${cfg.acme-path}";
              dnsChallenge = {
                provider = "cloudflare";
                resolvers = [ "1.1.1.1:53" "1.0.0.1:53" ];
              };
            };
          };
        };
        providers.docker.exposedByDefault = cfg.docker-provider;
        metrics = {
          prometheus = {
            entryPoint = "metrics";
            addEntryPointsLabels = true;
            addServicesLabels = true;
          };
        };
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
