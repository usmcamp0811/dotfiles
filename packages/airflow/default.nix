{ lib, pkgs, ... }:
with lib.campground;
let
  apache-airflow = mkPythonDerivation {
    inherit pkgs;
    name = "apache-airflow";
    src = ./.;
  };
in apache-airflow
