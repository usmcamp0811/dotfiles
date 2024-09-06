{ lib, pkgs, writeText, }:

let
  airflowVersion = "2.10.0"; # Use the correct version/tag from GitHub

  airflow = pkgs.python311Packages.buildPythonApplication {
    pname = "apache-airflow";
    version = airflowVersion;

    src = pkgs.fetchFromGitHub {
      owner = "apache";
      repo = "airflow";
      rev = airflowVersion;
      sha256 =
        "sha256-4pKRshuDyxA2Pad35DYH+TlDRwsJuLwnFIYdGSieBcw="; # Placeholder hash, update with the correct one
    };

    propagatedBuildInputs = with pkgs.python311Packages; [
      requests
      click
      flask
      # Add other dependencies here, or extract them from the Airflow repo
    ];

    meta = with lib; {
      description = "Apache Airflow workflow management platform";
      homepage = "https://airflow.apache.org/";
      # license = licenses.apache20;
      maintainers = with maintainers; [ matt-camp ]; # Add your maintainer info
    };
  };

in airflow
