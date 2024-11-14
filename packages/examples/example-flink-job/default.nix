{ lib, pkgs, ... }:
with lib;
with lib.campground;
let

  src = ./.;

  stream-job = pkgs.writeShellScriptBin "stream-job" ''
    ${example-flink-job.run-job}/bin/run-job ${src}/jobs/stream_job.py
  '';

  table-job = pkgs.writeShellScriptBin "table-job" ''
    ${example-flink-job.run-job}/bin/run-job ${src}/jobs/table_job.py
  '';

  example-flink-job = mkPyFlinkDerivation {
    inherit pkgs;
    name = "example-flink-job";
    src = src;
    flink-job-script = "jobs/stream_job.py";
    pypkgs-build-requirements = {
      avro = [ "setuptools" ];
      avro-python3 =
        [ "setuptools" "python-snappy" "zstandard" "isort" "pycodestyle" ];
      apache-flink = [ "setuptools" ];
      mocker = [ "setuptools" ];
      apache-flink-libraries = [ "setuptools" ];
    };
    additionalPassThru = {
      stream-job = stream-job;
      table-job = table-job;
    };
  };

in
example-flink-job
