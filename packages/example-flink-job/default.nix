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
      super."${package}".overridePythonAttrs (oldAttrs: {
        buildInputs = (oldAttrs.buildInputs or [ ])
          ++ (builtins.map (req: super."${req}") build-requirements);

        # Additional override for apache-flink-libraries to avoid collision
        installPhase = if package == "apache-flink-libraries" then ''
          rm -rf $out/lib/python3.11/site-packages/pyflink/__pycache__/version.cpython-311.pyc
        '' else
          oldAttrs.postInstall or "";
      })) pypkgs-build-requirements);

  python-env = pkgs.poetry2nix.mkPoetryEnv {
    projectDir = src;
    python = pkgs.python311;
    overrides = p2n-overrides;
    preferWheels = true; # Prefer wheels to speed up the build process
  };

  src = ./.;

  stream-job = pkgs.writeShellScriptBin "stream-job" ''
    ${run-job}/bin/run-job ${src}/jobs/stream-job.py
  '';

  table-job = pkgs.writeShellScriptBin "table-job" ''
    ${run-job}/bin/run-job ${src}/jobs/table-job.py
  '';

  example-flink-job = mkFlinkDerivation {
    inherit pkgs python-env;
    name = "example-flink-job";
    src = src;
    flink-job-script = "jobs/stream-job.py";
    additionalPassThru = {
      stream-job = stream-job;
      table-job = table-job;
    };
  };

in example-flink-job
