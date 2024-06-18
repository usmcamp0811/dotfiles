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

  # TODO: Figure out what is not needed
  flink-conf = pkgs.writeTextFile {
    name = "flink-conf.yaml";
    text = ''
      env.java.opts.all: --add-exports=java.base/sun.net.util=ALL-UNNAMED --add-exports=java.rmi/sun.rmi.registry=ALL-UNNAMED --add-exports=jdk.compiler/com.sun.tools.javac.api=ALL-UNNAMED --add-exports=jdk.compiler/com.sun.tools.javac.file=ALL-UNNAMED --add-exports=jdk.compiler/com.sun.tools.javac.parser=ALL-UNNAMED --add-exports=jdk.compiler/com.sun.tools.javac.tree=ALL-UNNAMED --add-exports=jdk.compiler/com.sun.tools.javac.util=ALL-UNNAMED --add-exports=java.security.jgss/sun.security.krb5=ALL-UNNAMED --add-opens=java.base/java.lang=ALL-UNNAMED --add-opens=java.base/java.net=ALL-UNNAMED --add-opens=java.base/java.io=ALL-UNNAMED --add-opens=java.base/java.nio=ALL-UNNAMED --add-opens=java.base/sun.nio.ch=ALL-UNNAMED --add-opens=java.base/java.lang.reflect=ALL-UNNAMED --add-opens=java.base/java.text=ALL-UNNAMED --add-opens=java.base/java.time=ALL-UNNAMED --add-opens=java.base/java.util=ALL-UNNAMED --add-opens=java.base/java.util.concurrent=ALL-UNNAMED --add-opens=java.base/java.util.concurrent.atomic=ALL-UNNAMED --add-opens=java.base/java.util.concurrent.locks=ALL-UNNAMED
      jobmanager.rpc.address: localhost
      jobmanager.rpc.port: 6123
      jobmanager.bind-host: 0.0.0.0
      jobmanager.memory.process.size: 1600m
      taskmanager.bind-host: 0.0.0.0
      taskmanager.host: localhost
      taskmanager.memory.process.size: 1728m
      taskmanager.numberOfTaskSlots: 1
      parallelism.default: 1
      jobmanager.execution.failover-strategy: region
      rest.address: localhost
      rest.port: 8081
      rest.bind-address: 0.0.0.0
      env.log.dir: /tmp/flink-logs
      env.java.home: ${pkgs.openjdk11}
      env.path: ${python-env}/bin/:$PATH
      python.path: ${python-env}/lib/python3.11/site-packages
      python.executable: ${python-env}/bin/python
      python.client.executable: ${python-env}/bin/python
    '';
  };

  flink-conf-dir = pkgs.stdenv.mkDerivation {
    name = "flink-conf-drv";
    src = src;
    phases = [ "installPhase" ];
    installPhase = ''
      mkdir -p $out/conf
      # Iterate over each file in the source directory
      for file in "${pkgs.flink}/opt/flink/conf"/*; do
          # Get the basename of the file
          basefile=$(basename "$file")
          if [ "$basefile" == "flink-conf.yaml" ]; then
              continue
          fi
          if [ "$basefile" == "config.yaml" ]; then
              continue
          fi
          # Create the symbolic link in the destination directory
          ln -s "$file" "$out/conf/$basefile"
      done
      cp ${flink-conf} $out/conf/flink-conf.yaml
      cp ${flink-conf} $out/conf/config.yaml
    '';
  };

  job = pkgs.writeShellScriptBin "job" ''
    # Check if FLINK_CONF_DIR is unset or empty
    if [ -z "$FLINK_CONF_DIR" ]; then
        export FLINK_CONF_DIR="${flink-conf-dir}/conf";
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

  stop-all = pkgs.writeShellScriptBin "stop-all" ''
    ${pkgs.flink}/opt/flink/bin/jobmanager.sh stop-all && ${pkgs.flink}/opt/flink/bin/taskmanager.sh stop-all
  '';

  run-tests = pkgs.writeShellScriptBin "run-tests" ''
    # Resolves the symlink to find the actual path of the script
    SCRIPT=$(readlink -f "$0" || realpath "$0")
    SCRIPT_DIR=$(dirname "$SCRIPT")

    export PATH=${python-env}/bin/:$PATH
    export PYTHONPATH="${python-env}/lib/python3.11/site-packages"
    export PYFLINK_PYTHON="${python-env}/bin/python"
    export JAVA_HOME=${pkgs.openjdk11};
    export FLINK_TESTING=1;
    export FLINK_CONF_DIR="${flink-conf-dir}/conf";
    export CLASSPATH=$(find ${pkgs.flink}/opt/flink/lib -name '*.jar' | tr '\n' ':'):${pkgs.campground.flink-connector-kafka}
    export FLINK_HOME=${pkgs.flink}/opt/flink
    export FLINK_CONNECTOR_JAR="file://${pkgs.campground.flink-connector-kafka}"

    # Adjusted to ensure it works regardless of where it's called from
    BASE_DIR=$(dirname "$SCRIPT_DIR")
    ${python-env}/bin/pytest $SCRIPT_DIR/tests/test_job.py "$@"
  '';

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
      description = "Tests for Example Flink Job";
      mainProgram = "run-tests";
    };
  };

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
      cp ${run-tests}/bin/run-tests $out/src/run-tests
      cp ${stop-all}/bin/stop-all $out/bin/stop-all
      cp -r ${flink-conf-dir}/conf $out/
    '';

    passthru = {
      python = python-env;
      test = test-flink-job;
      stop-all = stop-all;
      conf = flink-conf-dir;
    };
  };
in override-meta new-meta example-flink-job
