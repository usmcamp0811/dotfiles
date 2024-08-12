{ lib, pkgs, hosts ? { }, ... }:
with lib;
with lib.campground;
let
  new-meta = with lib; {
    description = "An Example PyFlink Job";
    license = licenses.asl20;
    maintainers = with maintainers; [ matt-camp ];
    mainProgram = "example-flink-job";
  };

  pypkgs-build-requirements = {
    avro = [ "setuptools" ];
    avro-python3 =
      [ "setuptools" "python-snappy" "zstandard" "isort" "pycodestyle" ];
    apache-flink = [ "setuptools" ];
    mocker = [ "setuptools" ];
    apache-flink-libraries = [ "setuptools" ];
  };

  p2n-overrides = pkgs.poetry2nix.defaultPoetryOverrides.extend (self: super:
    builtins.mapAttrs (package: build-requirements:
      let
        override = super."${package}".overridePythonAttrs (oldAttrs: {
          buildInputs = (oldAttrs.buildInputs or [ ])
            ++ (builtins.map (req: super."${req}") build-requirements);
        });
      in if package == "apache-flink-libraries" then
        override.overrideAttrs (oldAttrs: {
          postInstall = ''
            ${oldAttrs.postInstall or ""}
            rm -rf $out/lib/python3.11/site-packages/pyflink/__pycache__/version.cpython-311.pyc
          '';
        })
      else
        override) pypkgs-build-requirements);

  python-env = pkgs.poetry2nix.mkPoetryEnv {
    projectDir = src;
    python = pkgs.python311;
    overrides = p2n-overrides;
    preferWheels = true; # Prefer wheels to speed up the build process
  };

  src = ./.;

  stream-job = pkgs.writeShellScriptBin "stream-job" ''
    ${example-flink-job.run-job}/bin/run-job ${src}/jobs/stream_job.py
  '';

  table-job = pkgs.writeShellScriptBin "table-job" ''
    ${example-flink-job.run-job}/bin/run-job ${src}/jobs/table_job.py
  '';

  example-flink-job = mkFlinkDerivation {
    inherit pkgs python-env;
    name = "example-flink-job";
    src = src;
    flink-job-script = "jobs/stream_job.py";
    additionalPassThru = {
      stream-job = stream-job;
      table-job = table-job;
    };
  };

in example-flink-job
