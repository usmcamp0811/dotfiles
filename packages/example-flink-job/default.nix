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

  consumer = pkgs.writeShellScriptBin "consumer" ''
    # Check if FLINK_CONF_DIR is unset or empty
    if [ -z "$FLINK_CONF_DIR" ]; then
        export FLINK_CONF_DIR="/var/lib/flink/conf";
        echo "FLINK_CONF_DIR set to $FLINK_CONF_DIR"
    else
        echo "FLINK_CONF_DIR already set to $FLINK_CONF_DIR"
    fi
    if [ -z "$TOPIC" ]; then
        export TOPIC="example-topic";
        echo "TOPIC set to $TOPIC"
    else
        echo "TOPIC already set to $TOPIC"
    fi
    if [ -z "$BROKER" ]; then
        export BROKER="localhost:9092";
        echo "BROKER set to $BROKER"
    else
        echo "BROKER already set to $BROKER"
    fi

    export PATH=${pkgs.campground.example-flink-job.python}/bin/:$PATH
    export PYTHONPATH="${pkgs.campground.example-flink-job.python}/lib/python3.11/site-packages"
    export PYFLINK_PYTHON="${pkgs.campground.example-flink-job.python}/bin/python"
    ${pkgs.flink}/bin/flink run \
      -py ${src}/job/consumer.py \
      -pyclientexec ${python-env}/bin/python \
      --jarfile ${pkgs.campground.flink-connector-kafka}
  '';

  producer = pkgs.writeShellScriptBin "producer" ''
    # Check if FLINK_CONF_DIR is unset or empty
    if [ -z "$FLINK_CONF_DIR" ]; then
        export FLINK_CONF_DIR="/var/lib/flink/conf";
        echo "FLINK_CONF_DIR set to $FLINK_CONF_DIR"
    else
        echo "FLINK_CONF_DIR already set to $FLINK_CONF_DIR"
    fi
    if [ -z "$TOPIC" ]; then
        export TOPIC="example-topic";
        echo "TOPIC set to $TOPIC"
    else
        echo "TOPIC already set to $TOPIC"
    fi
    if [ -z "$BROKER" ]; then
        export BROKER="localhost:9092";
        echo "BROKER set to $BROKER"
    else
        echo "BROKER already set to $BROKER"
    fi

    export PATH=${pkgs.campground.example-flink-job.python}/bin/python:$PATH
    export PYTHONPATH="${pkgs.campground.example-flink-job.python}/lib/python3.11/site-packages"
    export PYFLINK_PYTHON="${pkgs.campground.example-flink-job.python}/bin/python"
    ${pkgs.flink}/bin/flink run \
      -py ${src}/job/producer.py \
      -pyclientexec ${python-env}/bin/python \
      --jarfile ${pkgs.campground.flink-connector-kafka}
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

  test-flink-job = pkgs.stdenv.mkDerivation {
    name = "test-flink-job";
    src = src;
    phases = [ "installPhase" ];
    propagatedBuildInputs = [ pkgs.openjdk11 python-env ];
    installPhase = ''
      mkdir -p $out/bin
      ln -s ${example-flink-job}/src/run-tests $out/bin/run-tests
    '';
    meta = {
      description = "Test for Example Flink Job";
      mainProgram = "run-tests";
    };
  };

  example-flink-job = pkgs.stdenv.mkDerivation {
    name = "example-flink-job";
    src = src;

    installPhase = ''
      mkdir -p $out/bin
      mkdir -p $out/src
      mkdir -p $out/opt/flink

      cp -r $src/* $out/src/
      cp -r ${python-env}/bin/* $out/bin/
      cp ${consumer}/bin/consumer $out/bin/
      cp ${producer}/bin/producer $out/bin/
      cp ${run-tests}/bin/run-tests $out/src/run-tests
    '';

    passthru = {
      python = python-env;
      test = test-flink-job;
      producer = producer;
      consumer = consumer;
    };
  };
in override-meta new-meta example-flink-job
