{ lib, pkgs, ... }:
with lib.campground;
let
  apache-airflow = mkPythonDerivation {
    inherit pkgs;
    name = "apache-airflow";
    src = ./.;
    installPhase = ''
      mkdir -p $out/bin
      cp -r ${apache-airflow.python}/bin/* $out/bin
    '';
    extraPackages = [ pkgs.rustc ];
    pypkgs-build-requirements = {
      apache-airflow-providers-amazon = [ "bcrypt" ];
    };
  };
in apache-airflow
