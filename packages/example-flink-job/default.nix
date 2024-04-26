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

  # ${python-env}/bin/python ${src}/job/job.py --jobname "example-flink-job" --inputtopic "example-topic" --outputtopic "example-output" --errortopic "example-error" --kafka_server "10.8.0.70:9092"
  # ${pkgs.flink}/bin/flink run -py ${src}/job/job.py -pyclientexec ${python-env}/bin/python
  # ${pkgs.campground.flink}/bin/flink run -py ${src}/job/job.py -pyclientexec ${python-env}/bin/python --classpath "${pkgs.campground.flink}/opt/flink/opt/*"
  flink-job = pkgs.writeShellScriptBin "flink-job" ''
    ${pkgs.campground.flink}/bin/flink run -py ${pkgs.campground.flink}/opt/flink/examples/python/datastream/process_json_data.py -pyclientexec ${python-env}/bin/python --classpath "${pkgs.campground.flink}/opt/flink/opt/*"
  '';

  run-tests = pkgs.writeShellScriptBin "run-tests" ''
    export JAVA_HOME=${pkgs.jdk11.home}
    export CLASSPATH=${pkgs.campground.flink-connector-kafka}/lib
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
    propagatedBuildInputs =
      [ pkgs.openjdk11 python-env pkgs.campground.flink-connector-kafka ];
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
    # propagatedBuildInputs = [
    #   pkgs.openjdk11
    #   pkgs.flink
    #   python-env
    #   pkgs.campground.flink-connector-kafka
    # ];
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
    passthru = {
      python = python-env;
      test = test-flink-job;
    };
  };
in override-meta new-meta example-flink-job
