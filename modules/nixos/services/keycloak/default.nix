{ config, lib, pkgs, ... }:
with lib;
with lib.fmf;
let
  cfg = config.fmf.services.keycloak;
  keycloakDir = "/var/lib/keycloak";
  sslCertificate = "${keycloakDir}/${cfg.domain}.cert";
  sslCertificateKey = "${keycloakDir}/${cfg.domain}.key";
  keycloak-db-pass = "${keycloakDir}/keycloak-db.pass";
  # TODO: Fix this thing.. it deploys but I can't login I get:
  # Danger alert:somethingWentWrong

in
{
  options.fmf.services.keycloak = with types; {
    enable = mkBoolOpt false "Whether or not to enable keycloak.";
    port = mkOpt int 19323 "Port to listen on";
    domain = mkOpt str "keycloak.lan.aicampground.com"
      "The domain part of the public URL used as base for all frontend requests.";

    role-id =
      mkOpt str config.fmf.services.vault-agent.settings.vault.role-id
        "Absolute path to the Vault role-id";
    secret-id =
      mkOpt str config.fmf.services.vault-agent.settings.vault.secret-id
        "Absolute path to the Vault secret-id";
    vault-path = mkOpt str "secret/campground/keycloak"
      "The Vault path to the KV containing the KVs that are for each database";
    vault-path-cert =
      mkOpt str "secret/campground/data/cloudflare/aicampground.com"
        "Vault path to the place the correct cert/key exist for TLS";
    kvVersion = mkOption {
      type = enum [ "v1" "v2" ];
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

    users = {
      users = {
        keycloak = {
          group = "keycloak";
          isSystemUser = true;
        };
      };
      groups = { keycloak = { }; };
    };

    systemd.services.keycloakSecrets = {
      description = "Get Keycloak Secrets";
      serviceConfig = {
        Type = "oneshot";
        User =
          "root"; # Use the root user to create the folder and set permissions
      };
      script = ''
        mkdir -p ${keycloakDir}
        ${pkgs.coreutils}/bin/cp /tmp/detsys-vault/keycloak-db.pass ${keycloak-db-pass}
        ${pkgs.coreutils}/bin/cp /tmp/detsys-vault/${cfg.domain}.cert ${sslCertificate}
        ${pkgs.coreutils}/bin/cp /tmp/detsys-vault/${cfg.domain}.key ${sslCertificateKey}
        chown -R keycloak:keycloak ${keycloakDir}
      '';
      wantedBy = [ "multi-user.target" ];
      before = [ "keycloakPostgreSQLInit.service" "keycloak.service" ];
    };

    services.keycloak = {
      enable = true;
      sslCertificateKey = sslCertificateKey;
      sslCertificate = sslCertificate;
      initialAdminPassword = "strongpassword";

      database = {
        type = "postgresql";
        createLocally = true;
        username = "keycloak";
        passwordFile = "${keycloak-db-pass}";
      };
      settings = {
        hostname = cfg.domain;
        http-enabled = true;
        health-enabled = true;
        hostname-admin-url = "${cfg.domain}";
        http-host = "0.0.0.0";
        http-port = cfg.port;
        https-port = cfg.port + 1;
        # hostname-strict-backchannel = true;
      };
      # themes = {
      #   keywind = pkgs.keycloak-keywind;
      # };
    };

    networking.firewall.allowedTCPPorts = [ cfg.port (cfg.port + 1) ];

    fmf.services.postgresql = {
      enable = true;
      authentication = [
        "local keycloak keycloak peer"
        "host keycloak keycloak 127.0.0.1/32 trust"
        "host keycloak keycloak 127.0.0.1/32 md5"
      ];
      databases = [{
        name = "keycloak";
        user = "keycloak";
      }];
    };

    fmf.services.vault-agent.services = {
      keycloakSecrets = {
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
              "${cfg.domain}.key" = {
                text = ''
                  {{ with secret "${cfg.vault-path-cert}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.key }}{{ else }}{{ .Data.data.key }}{{ end }}{{ end }}'';
                permissions = "0600";
                change-action = "restart";
              };
              "${cfg.domain}.cert" = {
                text = ''
                  {{ with secret "${cfg.vault-path-cert}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.cert }}{{ else }}{{ .Data.data.cert }}{{ end }}{{ end }}'';
                permissions = "0600";
                change-action = "restart";
              };
              "keycloak-db.pass" = {
                text = ''
                  {{ with secret "${cfg.vault-path}" }}{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.dbpass }}{{ else }}{{ .Data.data.dbpass }}{{ end }}{{ end }}'';
                permissions = "0600";
                change-action = "restart";
              };
            };
          };
        };
      };
    };
  };
}
