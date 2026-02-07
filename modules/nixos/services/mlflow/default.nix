{ lib, config, pkgs, ... }:
with lib;
with lib.fmf;
let
  cfg = config.fmf.services.mlflow;
  inherit (pkgs.fmf) mlflow;
in
{
  options.fmf.services.mlflow = with types; {
    enable = mkBoolOpt false "Enable an MLFlow;";
    port = mkOpt int 8000 "Port to Host the mlflow server on.";
    dbURI =
      mkOpt str "postgresql+psycopg2://mlflow:@/mlflow?host=/var/run/postgresql"
        "Backend DB URI";
    # dbURI = mkOpt str "mysql://mlflow:lflow@localhost/mlflow?unix_socket=/run/mysqld/mysqld.sock" "Backend DB URI";
    artifactRoot = mkOpt str "s3://mlflow" "Artifact Root Location";
    s3EndpointURL =
      mkOpt str "https://s3-api.lan.aicampground.com" "S3 Storage Endpoint URL";
    s3Region = mkOpt str "us-east-1" "S3 Region";

    role-id =
      mkOpt str config.fmf.services.vault-agent.settings.vault.role-id
        "Absolute path to the Vault role-id";
    secret-id =
      mkOpt str config.fmf.services.vault-agent.settings.vault.secret-id
        "Absolute path to the Vault secret-id";
    vault-path = mkOpt str "secret/campground/mlflow"
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
    users.users.mlflow = {
      isNormalUser = false;
      isSystemUser = true;
      description = "MLflow system user";
      group = "mlflow";
      extraGroups =
        [ "mlflow" ]; # Optional if you want the user to be in additional groups
    };

    users.groups.mlflow = { };

    fmf.services.postgresql = {
      enable = true;
      authentication = [ "local mlflow mlflow trust" ];
      databases = [{
        name = "mlflow";
        user = "mlflow";
      }];
    };

    # fmf.services.mysql = {
    #   enable = true;
    #   databases = [
    #     {
    #       name = "mlflow";
    #       user = "mlflow";
    #     }
    #   ];
    # };

    services.nginx = {
      enable = true;
      virtualHosts = {
        "mlflow.lan" = {
          http2 = true;
          listen = [{
            addr = "0.0.0.0";
            port = cfg.port;
          }]; # Specify the port here
          locations."/" = {
            proxyPass = "http://127.0.0.1:5000";
            proxyWebsockets = true;
          };
        };
      };
    };

    systemd.services.mlflow = {
      description = "MLflow tracking server";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      environment = {
        MLFLOW_BACKEND_STORE_URI = "${cfg.dbURI}";
        MLFLOW_ARTIFACT_URI = "${cfg.artifactRoot}";
        MLFLOW_S3_ENDPOINT_URL = "${cfg.s3EndpointURL}";
        MLFLOW_S3_IGNORE_TLS = "true";
        AWS_DEFAULT_REGION = "${cfg.s3Region}";
        MLFLOW_DEFAULT_ARTIFACT_ROOT = "${cfg.artifactRoot}";
        MLFLOW_HOST = "0.0.0.0";
        MLFLOW_PORT = "5000";
      };
      # Use a preStart script to ensure the database is initialized or upgraded before the server starts
      # preStart = ''
      #   ${pkgs.fmf.mlflow}/bin/mlflow-server db upgrade '${cfg.dbURI}'
      # '';
      script = ''
        ${pkgs.mlflow-server}/bin/mlflow-server server --backend-store-uri '${cfg.dbURI}' --artifacts-destination ${cfg.artifactRoot} --host 127.0.0.1 --port 5000
      '';
      serviceConfig = {
        User = "mlflow";
        WorkingDirectory = "/var/lib/mlflow";
        ReadWritePaths = [ "/var/lib/mlflow" ];
        Restart = "always";
      };
    };

    systemd.tmpfiles.rules = [
      "d /var/lib/mlflow 0755 mlflow mlflow -"
      "d /var/lib/mlflow/tmp 0755 mlflow mlflow -"
    ];
    networking.firewall.allowedTCPPorts = [ cfg.port ];

    fmf.services.vault-agent.services.mlflow = {
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
        mlflow = {
          text = ''
            {{ with secret "${cfg.vault-path}" }}
            AWS_ACCESS_KEY_ID='{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.AWS_ACCESS_KEY_ID }}{{ else }}{{ .Data.data.AWS_ACCESS_KEY_ID }}{{ end }}'
            AWS_SECRET_ACCESS_KEY='{{ if eq "${cfg.kvVersion}" "v1" }}{{ .Data.AWS_SECRET_ACCESS_KEY }}{{ else }}{{ .Data.data.AWS_SECRET_ACCESS_KEY }}{{ end }}'
            {{ end }}
          '';
        };
      };
    };
  };
}
