{
  lib,
  pkgs,
  config,
  virtual,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.security.acme;
  # STILL A WIP.. didn't get acme fully working yet.
in {
  options.fmf.security.acme = with lib.types; {
    enable = mkEnableOption "default ACME configuration";
    email = mkOpt str config.fmf.user.email "The email to use.";
    staging = mkOpt bool virtual "Whether to use the staging server or not.";
    dnsProvider = mkOpt str "cloudflare" "DNS Provider";
    credentialsFile =
      mkOpt str "/var/lib/vault/cloudflare.env" "The credentials File.";

    role-id =
      mkOpt str config.fmf.services.vault-agent.settings.vault.role-id
      "Absolute path to the Vault role-id";
    secret-id =
      mkOpt str config.fmf.services.vault-agent.settings.vault.secret-id
      "Absolute path to the Vault secret-id";
    vault-path =
      mkOpt str "secret/campground/cloudflare"
      "The Vault path to the KV containing the KVs that are for each database";
    kvVersion = mkOption {
      type = enum ["v1" "v2"];
      default = "v2";
      description = "KV store version";
    };
    vault-address = mkOption {
      type = str;
      default = config.fmf.services.vault-agent.settings.vault.address;
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
        server =
          mkIf cfg.staging
          "https://acme-staging-v02.api.letsencrypt.org/directory";

        reloadServices =
          optional config.services.traefik.enable "traefik.service";
        credentialsFile = cfg.credentialsFile;
      };
      certs = {
        "aicampground.com" = {
          extraDomainNames = [
            "*.aicampground.com"
            "*.lan.aicampground.com"
          ]; # Add additional domains if needed
        };
      };
    };

    systemd.services.copyDNSCreds = {
      description = "Copy DNS Provider Key and adjust ownership";
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        ExecStart = "${pkgs.coreutils}/bin/sh -c 'cp /tmp/detsys-vault/cloudflare.env /var/lib/vault/cloudflare.env && chown acme:acme /var/lib/vault/cloudflare.env'";
      };
    };

    fmf = {
      services = {
        vault-agent = {
          services = {
            "copyDNSCreds" = {
              settings = {
                vault.address = cfg.vault-address;
                auto_auth = {
                  method = [
                    {
                      type = "approle";
                      config = {
                        role_id_file_path = cfg.role-id;
                        secret_id_file_path = cfg.secret-id;
                        remove_secret_id_file_after_reading = false;
                      };
                    }
                  ];
                };
              };
              secrets = {
                file = {
                  files = {
                    "cloudflare.env" = {
                      text = ''
                        {{ with secret "${cfg.vault-path}" }}
                          CF_API_KEY='{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.CF_API_KEY }}{{ else }}{{ .Data.data.CF_API_KEY }}{{ end }}'
                          CLOUDFLARE_EMAIL='{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.CLOUDFLARE_EMAIL }}{{ else }}{{ .Data.data.CLOUDFLARE_EMAIL }}{{ end }}'
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
