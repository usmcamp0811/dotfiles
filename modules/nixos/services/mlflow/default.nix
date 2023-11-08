{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
let
  cfg = config.campground.services.mlflow;
  mlflowPlusPostgres = pkgs.python3.withPackages (ps: with ps; [
    mlflow
    psycopg2  
    gunicorn
  ]);
in
{
  options.campground.services.mlflow = with types; {
    enable = mkBoolOpt false "Enable an MLFlow;";
    port = mkOpt int 8000 "Port to Host the mlflow server on.";
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

    environment.systemPackages = with pkgs; [
      mlflow-server
      python3Packages.mlflow
    ];

    # services.nginx = {
    #   enable = true;
    #   virtualHosts = {
    #     "mlflow.lan" = {
    #       http2 = true;
    #       locations."/" = {
    #         proxyPass = "http://127.0.0.1:5000";
    #         proxyWebsockets = true;
    #       };
    #     };
    #   };
    # };
# --backend-store-uri ${pgUri} 
    systemd.services.mlflow = {
      description = "MLflow tracking server";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        User = "mlflow";
        ExecStart = let
          pgUri = "postgresql+psycopg2://mlflow:@/mlflow?host=/var/run/postgresql";
          artifactRoot = "/var/lib/mlflow";
        in "${pkgs.python3Packages.mlflow}/bin/mlflow server --default-artifact-root file://${artifactRoot} --host 0.0.0.0 --port 5000";
        # environment = {
        #   PYTHONPATH="${myPythonEnv}/${pkgs.python3.sitePackages}";
        # };
        Restart = "always";
        ProtectSystem = "strict";
        ReadWritePaths = [ "/var/lib/mlflow" ];
      };
    };


    networking.firewall.allowedTCPPorts = [ cfg.port ];
  };
}
