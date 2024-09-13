{ pkgs, ... }:

pkgs.runCommand "mlflow" { src = ./.; } ''
  mkdir -p $out
  ${pkgs.campground.mlflow}/bin/mlflow > $out/results.txt
''
