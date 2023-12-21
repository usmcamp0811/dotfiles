{ lib
, writeText
, writeShellApplication
, substituteAll
, gum
, inputs
, pkgs
, hosts ? { }
, ...
}:
with lib;
with lib.campground;
let
  inherit (lib) mapAttrsToList concatStringsSep;
  inherit (lib.campground) override-meta;
  # allows us to just use the app/package
  # inherit (pkgs.campground) campground;

  new-meta = with lib; {
    description = "A Simple mlFlow App Container Image";
    license = licenses.mit;
    maintainers = with maintainers; [ mattcamp ];
  };

  container-mlflow = pkgs.dockerTools.buildLayeredImage{
    name = "mlflow-app" ;
    tag = "latest";
    contents = [ pkgs.campground.mlflow pkgs.bash pkgs.coreutils ];
    extraCommands = ''
      mkdir -p usr/bin
      cat ${pkgs.campground.mlflow}/bin/mlflow-server > usr/bin/mlflow-server
      chmod +x usr/bin/mlflow-server
    '';
    config = {
      Entrypoint = [
      "mlflow-server"
      ];
      ExposedPorts = {
        "5000/tcp" = {};
      };
      Env = [
        "PATH=${pkgs.coreutils}/bin/:/usr/bin/"
        "MLFLOW_S3_IGNORE_TLS=true"
        "MLFLOW_HOST=0.0.0.0"
        "MLFLOW_PORT=5000"
      ];
    };
  };
in
override-meta new-meta container-mlflow
