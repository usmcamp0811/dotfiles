{ config, lib, pkgs, ... }:
with lib;
with lib.campground;
let cfg = config.campground.services.keycloak;
in {
  options.campground.services.keycloak = with types; {
    enable = mkBoolOpt false "Whether or not to enable keycloak.";
    port = mkOpt int 19323 "Port to listen on";
    domain = mkOpt str "keycloak.lan.aicampground.com"
      "The domain part of the public URL used as base for all frontend requests.";

    role-id =
      mkOpt str config.campground.services.vault-agent.settings.vault.role-id
        "Absolute path to the Vault role-id";
    secret-id =
      mkOpt str config.campground.services.vault-agent.settings.vault.secret-id
        "Absolute path to the Vault secret-id";
    vault-path = mkOpt str "secret/campground/keycloak"
      "The Vault path to the KV containing the KVs that are for each database";
    vault-path-cert =
      mkOpt str "secret/campground/data/cloudflare/aicampground.com";
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
        mkdir -p /var/lib/keycloak
        ${pkgs.coreutils}/bin/cp /tmp/detsys-vault/keycloak-db.pass /var/lib/keycloak/keycloak-db.pass
        ${pkgs.coreutils}/bin/cp /tmp/detsys-vault/${cfg.domain}.key /var/lib/keycloak/${cfg.domain}.key
        ${pkgs.coreutils}/bin/cp /tmp/detsys-vault/${cfg.domain}.cert /var/lib/keycloak/${cfg.domain}.cert
        chown -R keycloak:keycloak /var/lib/keycloak
      '';
      wantedBy = [ "multi-user.target" ];
      before = [ "keycloakPostgreSQLInit.service" "keycloak.service" ];
    };

    services.keycloak = {
      enable = true;

      database = {
        type = "postgresql";
        createLocally = true;
        username = "keycloak";
        passwordFile = "/var/lib/vault/keycloak-db.pass";
      };

      settings = {
        hostname = cfg.domain;
        # hostname-admin-url = "https://${cfg.domain}";
        http-port = cfg.port;
        http-host = "0.0.0.0";
        # hostname-strict-backchannel = true;
        proxy-headers = "edge";
      };
      # themes = {
      #   keywind = pkgs.keycloak-keywind;
      # };
    };

    campground.services.postgresql = {
      enable = true;
      authentication = [ "host keycloak keycloak 127.0.0.1/32 trust" ];
      databases = [{
        name = "keycloak";
        user = "keycloak";
      }];
    };

    campground.services.vault-agent.services = {
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
