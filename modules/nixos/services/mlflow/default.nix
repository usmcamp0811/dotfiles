{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
let
  cfg = config.campground.services.mlflow;
in
{
  options.campground.services.mlflow = with types; {
    enable = mkBoolOpt false "Enable an MLFlow;";
    port = mkOpt str "1234" "Port to Host the mlflow server on.";
  };

  config = mkIf cfg.enable {
    services.nginx = {
      enable = true;
      recommendedGzipSettings = true;
      recommendedOptimisation = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;
      virtualHosts."mlflow.lan" = {
        locations."/".proxyPass = "http://127.0.0.1:${toString cfg.port}";
      };
    };

    services.uwsgi = {
      enable = true;
      plugins = [ "python" ];
      instances = {
        mlflow = {
          plugins = [ "python3" ];
          socket = "127.0.0.1:${toString cfg.port}";
          wsgi-file = "${pkgs.writeScript "mlflow_wsgi.py" ''
            from mlflow.server import app
            if __name__ == "__main__":
                app.run()
          ''}";
          processes = 4;
          chmod-socket = "660";
          vacuum = true;
          die-on-term = true;
        };
      };
    };

    systemd.services.mlflow = {
      description = "MLflow tracking server";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.mlflow}/bin/mlflow server --host 127.0.0.1 --port ${toString cfg.port}";
        Restart = "always";
      };
    };

    networking.firewall.allowedTCPPorts = [ cfg.port ];
  };
}
