{ lib, pkgs, config, virtual, ... }:

let
  inherit (lib) mkIf mkEnableOption optional;
  inherit (lib.campground) mkOpt;

  cfg = config.campground.security.acme;
in
{
  options.campground.security.acme = with lib.types; {
    enable = mkEnableOption "default ACME configuration";
    email = mkOpt str config.campground.user.email "The email to use.";
    staging = mkOpt bool virtual "Whether to use the staging server or not.";
    dnsProvider = mkOpt str "cloudflare" "Default DNS Provider";

    role-id = mkOpt types.str config.campground.services.vault-agent.settings.vault.role-id "Absolute path to the Vault role-id";
    secret-id = mkOpt types.str config.campground.services.vault-agent.settings.vault.secret-id "Absolute path to the Vault secret-id";
    vault-path = mkOpt types.str "secret/campground/acme" "The Vault path to the KV containing the KVs that are for each database";
    kvVersion = mkOption {
      type = types.enum ["v1" "v2"];
      default = "v2";
      description = "KV store version";
    };
    vault-address = mkOption {
      type = types.str;
      default = config.campground.services.vault-agent.settings.vault.address;
      description = "The address of your Vault";
    };
  };

  config = mkIf cfg.enable {

    security.acme = {
      acceptTerms = true;

      defaults = {
        inherit (cfg) email;

        dnsProvider = cfg.dnsProvider;
        group = mkIf config.services.traefik.enable "traefik";
        server = mkIf cfg.staging "https://acme-staging-v02.api.letsencrypt.org/directory";

        # Reload nginx when certs change.
        reloadServices = optional config.services.traefik.enable "traefik.service";
      };

          security.acme.defaults.email = "default@example.com";
          security.acme.defaults.dnsProvider = "cloudflare";
          security.acme.defaults.credentialsFile = "/var/run/secrets/cloudflare";
      certs = {
        "aicampground.com" = {
          extraDomainNames = [ "*.aicampground.com" ]; # Add additional domains if needed
          dnsProviderCredentialsFile = "/etc/nixos/cloudflare.ini";
          challengeType = "dns-01";
        };
      };
    };

    campground = {
      services = {
        vault-agent = {
          services = {
            "acme" = {
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
              secrets = {
                file = {
                  files = {
                    "cloudflare.dns" = {
                      text = ''
                        {{ with secret "${cfg.vault-path}" }}
                        CI_SERVER_URL='{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.${CI_SERVER_URL} }}{{ else }}{{ .Data.data.${CI_SERVER_URL} }}{{ end }}'
                        REGISTRATION_TOKEN='{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.${REGISTRATION_TOKEN} }}{{ else }}{{ .Data.data.${REGISTRATION_TOKEN} }}{{ end }}'
                        {{ end }}
                      '';
                      permissions = "0600";
                      change-action = "restart";
                    };
                  };
                };
              };
            };
          };
        };
      };
    };
  };
}


# Credentials
CF_API_EMAIL=your_account_email_here
CF_API_KEY=your_api_key_here
CF_DNS_API_TOKEN=your_dns_edit_api_token_here
CF_ZONE_API_TOKEN=your_zone_read_api_token_here
CLOUDFLARE_API_KEY=your_api_key_here
CLOUDFLARE_DNS_API_TOKEN=your_dns_edit_api_token_here
CLOUDFLARE_EMAIL=your_account_email_here
CLOUDFLARE_ZONE_API_TOKEN=your_zone_read_api_token_here

# Additional Configuration
CLOUDFLARE_HTTP_TIMEOUT=your_api_request_timeout_here
CLOUDFLARE_POLLING_INTERVAL=your_dns_propagation_check_interval_here
CLOUDFLARE_PROPAGATION_TIMEOUT=your_max_waiting_time_for_dns_propagation_here
CLOUDFLARE_TTL=your_txt_record_ttl_here

# Configure ACME appropriately
security.acme.defaults.email = "admin+acme@example.com";
security.acme.defaults = {
  dnsProvider = "rfc2136";
  environmentFile = "/var/lib/secrets/certs.secret";
  # We don't need to wait for propagation since this is a local DNS server
  dnsPropagationCheck = false;
};

# For each virtual host you would like to use DNS-01 validation with,
# set acmeRoot = null
services.nginx = {
  enable = true;
  virtualHosts = {
    "foo.example.com" = {
      enableACME = true;
      acmeRoot = null;
    };
  };
};
