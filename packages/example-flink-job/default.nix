{ lib, pkgs, hosts ? { }, ... }:
let
  inherit (lib) mapAttrsToList concatStringsSep;
  inherit (lib.campground) override-meta;

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

  job = pkgs.writeShellScriptBin "job" ''
    # Check if FLINK_CONF_DIR is unset or empty
    if [ -z "$FLINK_CONF_DIR" ]; then
        echo "FLINK_CONF_DIR set to $FLINK_CONF_DIR"
    else
        echo "FLINK_CONF_DIR already set to $FLINK_CONF_DIR"
    fi
    if [ -z "$KAFKA_BROKER" ]; then
        export KAFKA_BROKER="localhost:9092";
        echo "KAFKA_BROKER set to $KAFKA_BROKER"
    else
        echo "KAFKA_BROKER already set to $KAFKA_BROKER"
    fi

    export PATH=${python-env}/bin/:$PATH
    export PYTHONPATH="${python-env}/lib/python3.11/site-packages"
    export PYFLINK_PYTHON="${python-env}/bin/python"
    export JAVA_HOME=${pkgs.openjdk11};
    export FLINK_HOME=${pkgs.flink}/opt/flink

    ${pkgs.flink}/opt/flink/bin/jobmanager.sh start
    ${pkgs.flink}/opt/flink/bin/taskmanager.sh start

    ${pkgs.flink}/bin/flink run \
      -py ${src}/job/job.py \
      -pyclientexec python \
      --jarfile ${pkgs.campground.flink-connector-kafka} &
  '';

  example-flink-job = pkgs.stdenv.mkDerivation {
    name = "example-flink-job";
    src = src;

    installPhase = ''
      mkdir -p $out/bin
      mkdir -p $out/src
      mkdir -p $out/opt/flink/conf

      cp -r $src/* $out/src/
      cp -r ${pkgs.flink}/opt/flink $out/opt/
      cp -r ${python-env}/bin/* $out/bin/
      cp ${job}/bin/job $out/bin/example-flink-job
    '';

    # passthru = {
    #   python = python-env;
    #   test = test-flink-job;
    #   stop-all = stop-all;
    #   conf = flink-conf-dir;
    # };
  };
in override-meta new-meta example-flink-job
