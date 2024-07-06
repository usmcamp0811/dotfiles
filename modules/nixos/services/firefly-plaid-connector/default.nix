{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
let
  cfg = config.campground.services.firefly-plaid-connector;
  ff = config.campground.services.firefly;
  application_yaml = ./application_yaml;
in {
  options.campground.services.firefly-plaid-connector = with types; {
    enable = mkBoolOpt false "Enable Firefly III.";
    role-id =
      mkOpt str config.campground.services.vault-agent.settings.vault.role-id
      "Absolute path to the Vault role-id";
    secret-id =
      mkOpt str config.campground.services.vault-agent.settings.vault.secret-id
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
      default = config.campground.services.vault-agent.settings.vault.address;
      description = "The address of your Vault";
    };
  };

  config = mkIf cfg.enable {

    services.docker.enable = true;

    # Define the oneshot service (if needed)
    systemd.services.setup-firefly-paid-connector = {
      description = "Setup for Firefly Paid Connector";
      wantedBy = [ "multi-user.target" ];
      environment = {
        TIMEZONE = "US/Central";
        FIREFLY_URL = ff.virtualHost;
        AMEX_FIREFLY_ACCOUT_ID = "8";
        USAA_FIREFLY_ACCOUT_ID = "1";
      };
      after = [ "network.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = ''
          #!/bin/bash
          echo "Running setup script for Firefly Paid Connector..."
          cat ${application_yaml} | ${pkgs.envsubst}/bin/envsubst > ${ff.dataDir}/application.yaml
          chown ${ff.firefly-user}:${ff.firefly-group} ${ff.dataDir}/application.yaml
        '';
      };
    };

    # Define the container
    virtualisation.oci-containers = {
      containers.firefly-paid-connector = {
        image = "ghcr.io/dvankley/firefly-plaid-connector-2:latest";
        hostname = "plaidconnector";
        volumes = [{
          source = "${ff.dataDir}/application.yaml";
          target = "/opt/fpc-config/application.yml";
          type = "bind";
          readOnly = true;
        }];
        environment = {
          SPRING_CONFIG_LOCATION = "/opt/fpc-config/application.yml";
        };
        autoStart = true;
        restartPolicy = "always";
        startTimeout = 90;
        after = [
          "setup-firefly-paid-connector.service"
        ]; # Make container service depend on oneshot service
      };
    };

    campground.services.vault-agent.services.setup-firefly-paid-connector = {
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
            PLAID_CLIENT_ID='{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.plaid_clinet_id }}{{ else }}{{ .Data.data.plaid_clinet_id }}{{ end }}'
            PLAID_SECRET='{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.plaid_secret }}{{ else }}{{ .Data.data.plaid_secret }}{{ end }}'
            USAA_ACCOUT_ID='{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.usaa_item_id }}{{ else }}{{ .Data.data.usaa_item_id  }}{{ end }}'
            USAA_ACCESS_TOKEN='{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.usaa_access_token  }}{{ else }}{{ .Data.data.usaa_access_token }}{{ end }}'
            AMEX_ACCOUT_ID='{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.amex_item_id }}{{ else }}{{ .Data.data.amex_item_id  }}{{ end }}'
            AMEX_ACCESS_TOKEN='{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.amex_access_token  }}{{ else }}{{ .Data.data.amex_access_token }}{{ end }}'
            {{ end }}
          '';
        };
      };
    };
  };
}
