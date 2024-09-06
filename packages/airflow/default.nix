{
  lib,
  pkgs,
  writeText,
}:

let
  airflowVersion = "2.10.0";

  airflow = pkgs.python311Packages.buildPythonPackage {
    pname = "apache-airflow";
    version = airflowVersion;

    src = pkgs.fetchPypi {
      pname = "apache-airflow";
      version = airflowVersion;
      sha256 = "sha256-+ycJlxbY8DYECMjKhtadv+1ERVg0tw0VBiUKvlIbU1o=";
    };
    doCheck = false;

    propagatedBuildInputs = with pkgs.python311Packages; [
      requests
      click
      flask
    ];

    meta = with lib; {
      description = "Apache Airflow workflow management platform";
      homepage = "https://airflow.apache.org/";
      maintainers = with maintainers; [ matt-camp ]; # Add your maintainer info
    };
  };

in
airflow
