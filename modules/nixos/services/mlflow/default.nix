{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
let
  cfg = config.campground.services.mlflow;
  inherit (pkgs.campground) mlflow;
  pythonEnv = pkgs.python3.withPackages (ps: with ps; [
    mlflow
    boto3
    gunicorn
    mysqlclient
    psycopg2
    # add any other Python packages your MLflow server requires
  ]);
in
{
  options.campground.services.mlflow = with types; {
    enable = mkBoolOpt false "Enable an MLFlow;";
    port = mkOpt int 8000 "Port to Host the mlflow server on.";
    dbURI = mkOpt str "postgresql+psycopg2://mlflow:@/mlflow?host=/var/run/postgresql" "Backend DB URI";
    artifactRoot = mkOpt str "/var/lib/mlflow" "Artifact Root Location";

  };

  config = mkIf cfg.enable {

    users.users.mlflow = {
      isNormalUser = false;
      isSystemUser = true;
      description = "MLflow system user";
      group = "mlflow";
      extraGroups = [ "mlflow" ]; # Optional if you want the user to be in additional groups
    };

    users.groups.mlflow = {};

    campground.services.postgresql = {
      enable = true;
      # TODO: configure authentication in a way that its set here and doesn't break other places
      # authentication = ''
      #   local all root trust
      #   local all postgres peer
      #   local vaultwarden vaultwarden trust
      #   local mattermost mattermost trust
      #   host  all  all  0.0.0.0/0  reject
      #   host  all  all  ::0/0  reject
      # '';
      databases = [ 
        { 
          name = "mlflow"; 
          user = "mlflow"; 
        } 
      ];
    };

    services.nginx = {
      enable = true;
      virtualHosts = {
        "mlflow.lan" = {
          http2 = true;
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
        # MLFLOW_BACKEND_STORE_URI="${cfg.dbURI}";
        MLFLOW_BACKEND_STORE_URI="file:///var/lib/mlflow";
        MLFLOW_ARTIFACT_ROOT="file:///var/lib/mlflow/artifacts";

        # MLFLOW_DEFAULT_ARTIFACT_ROOT="${cfg.artifactRoot}";
        MLFLOW_HOST="0.0.0.0";
        MLFLOW_PORT="5000";
        # MLFLOW_BACKEND_STORE_URI="${cfg.artifactRoot}";
      };
      # script = ''
      #   ${pkgs.mlflow-server}/bin/mlflow server
      #
      # '';
      serviceConfig = {
        User = "mlflow";
        ExecStart = "${pkgs.campground.mlflow}/bin/gunicornMlflow -b 127.0.0.1:5000 --worker-tmp-dir /var/lib/mlflow/tmp --workers 4 'mlflow.server:app'";
        WorkingDirectory = "/var/lib/mlflow";
        # Restart = "always";
        # ProtectSystem = "strict";
        ReadWritePaths = [ "/var/lib/mlflow" ];
      };
    };


    networking.firewall.allowedTCPPorts = [ cfg.port ];
  };
}
