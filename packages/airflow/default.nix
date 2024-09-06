{ lib, pkgs, ... }:
let

  airflowVersion = "2.10.0";
  pythonVersion = builtins.substring 0 3 (
    builtins.stringAfter "Python " (pkgs.python3.interpreter.python.version)
  );
  constraintUrl = "https://raw.githubusercontent.com/apache/airflow/constraints-${airflowVersion}/constraints-${pythonVersion}.txt";
in
pkgs.python3Packages.buildPythonPackage rec {
  pname = "apache-airflow";
  version = airflowVersion;

  src = pkgs.fetchPypi {
    inherit pname version;
    sha256 = "<insert-correct-sha256>";
  };

  propagatedBuildInputs = [
    pkgs.python3
    pkgs.requests # or any other dependencies
  ];

  meta = with pkgs.lib; {
    description = "Apache Airflow workflow management platform";
    homepage = "https://airflow.apache.org/";
    license = licenses.apache20;
  };

  # The installation phase where you pass the constraint file.
  postInstall = ''
    pip install . --constraint ${constraintUrl}
  '';
}
