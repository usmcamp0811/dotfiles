{ lib, config, pkgs, ... }:
with lib;
with lib.fmf;
let
  cfg = config.fmf.services.firefly-plaid-connector;
  ff = config.fmf.services.firefly;
  application_yaml = ./application.yml;
in {
  options.fmf.services.firefly-plaid-connector = with types; {
    enable = mkBoolOpt false "Enable Firefly III.";
    role-id =
      mkOpt str config.fmf.services.vault-agent.settings.vault.role-id
      "Absolute path to the Vault role-id";
    secret-id =
      mkOpt str config.fmf.services.vault-agent.settings.vault.secret-id
      "Absolute path to the Vault secret-id";
    vault-path = mkOpt str "secret/campground/plaid"
      "The Vault path to the KV containing the KVs that are for each database";
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

    # Define the oneshot service (if needed)
    systemd.services.setup-firefly-plaid-connector3 = {
      description = "Setup for Firefly Paid Connector";
      wantedBy = [ "multi-user.target" ];
      environment = {
        TIMEZONE = "US/Central";
        FIREFLY_URL = "https://${ff.virtualHost}";
        AMEX_FIREFLY_ACCOUT_ID = "424";
        USAA_FIREFLY_CHECKING_ACCOUT_ID = "418";
        USAA_FIREFLY_SAVING_ACCOUT_ID = "420";
        USAA_FIREFLY_SHARED_CHECKING_ACCOUT_ID = "422";

      };
      after = [ "network.target" ];
      before = [ "podman-firefly-plaid-connector.service" ];
      script = ''
        echo "Running setup script for Firefly Paid Connector..."
        cat ${application_yaml} | ${pkgs.envsubst}/bin/envsubst > ${ff.dataDir}/application.yaml
        mkdir -p ${ff.dataDir}/fpc-cursors
        chown 1002:1000 ${ff.dataDir}/application.yaml
        chown -R 1002:1000 ${ff.dataDir}/fpc-cursors
        chmod 600 ${ff.dataDir}/application.yaml
      '';
      serviceConfig = { Type = "oneshot"; };
    };

    # Define the container
    virtualisation.oci-containers = {
      containers.firefly-plaid-connector = {
        image = "ghcr.io/dvankley/firefly-plaid-connector-2:latest";
        hostname = "plaidconnector";
        volumes = [
          "${ff.dataDir}/application.yaml:/opt/fpc-config/application.yml"
          "${ff.dataDir}/fpc-cursors:/opt/fpc-cursors"
        ];
        environment = {
          SPRING_CONFIG_LOCATION = "/opt/fpc-config/application.yml";
          FIREFLYPLAIDCONNECTOR2_POLLED_CURSORFILEDIRECTORYPATH =
            "/opt/fpc-cursors";
        };
        autoStart = true;
        # extraOptions = [ "--restart=always" ];
      };
    };

    fmf.services.vault-agent.services.setup-firefly-plaid-connector3 = {
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
        plaid = {
          text = ''
            {{ with secret "${cfg.vault-path}" }}
            USAA_SHARED_CHECKING_ACCOUNT_ID='{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.usaa_shared_checking_id }}{{ else }}{{ .Data.data.usaa_shared_checking_id  }}{{ end }}'
            USAA_CHECKING_ACCOUNT_ID='{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.usaa_checking_id  }}{{ else }}{{ .Data.data.usaa_checking_id  }}{{ end }}'
            USAA_SAVINGS_ACCOUNT_ID='{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.usaa_savings_id }}{{ else }}{{ .Data.data.usaa_savings_id  }}{{ end }}'
            USAA_ACCESS_TOKEN='{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.usaa_access_token  }}{{ else }}{{ .Data.data.usaa_access_token }}{{ end }}'
            AMEX_ACCOUNT_ID='{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.amex_account_id  }}{{ else }}{{ .Data.data.amex_account_id  }}{{ end }}'
            AMEX_ACCESS_TOKEN='{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.amex_access_token  }}{{ else }}{{ .Data.data.amex_access_token }}{{ end }}'
            FIREFLY_PERSONAL_ACCESS_TOKEN='{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.firefly_personal_access_token  }}{{ else }}{{ .Data.data.firefly_personal_access_token }}{{ end }}'
            PLAID_SECRET='{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.plaid_secret }}{{ else }}{{ .Data.data.plaid_secret }}{{ end }}'
            PLAID_CLIENT_ID='{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.plaid_client_id   }}{{ else }}{{ .Data.data.plaid_client_id }}{{ end }}'
            {{ end }}
          '';
        };
      };
    };
  };
}
