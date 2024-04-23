{ lib, writeText, writeShellApplication, substituteAll, inputs, pkgs
, hosts ? { }, ... }:
let
  inherit (lib) mapAttrsToList concatStringsSep;
  inherit (lib.campground) override-meta;

  new-meta = with lib; {
    description = "An Example Flink Job";
    license = licenses.asl20;
    maintainers = with maintainers; [ matt-camp ];
    mainProgram = "flink-job";
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

  src = ./.;

  flink-job = pkgs.writeShellScriptBin "flink-job" ''
    ${python-env}/bin/python ${src}/job/job.py
  '';

  run-tests = pkgs.writeShellScriptBin "run-tests" ''
    # Resolves the symlink to find the actual path of the script
    SCRIPT=$(readlink -f "$0" || realpath "$0")
    SCRIPT_DIR=$(dirname "$SCRIPT")

    # Adjusted to ensure it works regardless of where it's called from
    BASE_DIR=$(dirname "$SCRIPT_DIR")
    ${python-env}/bin/pytest $SCRIPT_DIR/tests/test_job.py "$@"
  '';

  python-env = pkgs.poetry2nix.mkPoetryEnv {
    projectDir = src;
    python = pkgs.python311;
    overrides = p2n-overrides;
    preferWheels = true; # Prefer wheels to speed up the build process
  };

  example-flink-job = pkgs.stdenv.mkDerivation {
    name = "example-flink-job";
    src = src;
    phases = [ "installPhase" ];
    installPhase = ''
      mkdir -p $out/bin
      mkdir -p $out/src/
      cp -r $src/* $out/src/
      cp ${run-tests}/bin/run-tests $out/src/run-tests
      cp ${flink-job}/bin/flink-job $out/bin
      cp -r ${python-env}/bin/* $out/bin
      ln -s $out/src/run-tests $out/bin/run-tests
    '';
    passthru = { python = python-env; };
  };
in override-meta new-meta example-flink-job
