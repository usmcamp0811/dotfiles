{ lib, inputs, snowfall-inputs, }: rec {
  ## Create a Flink configuration directory derivation
  createFlinkConfDir = { pkgs, flinkConf }:
    pkgs.stdenv.mkDerivation {
      name = "flink-conf-drv";
      phases = [ "installPhase" ];
      installPhase = ''
        mkdir -p "$out/conf"
        for file in "${pkgs.flink}/opt/flink/conf"/*; do
          basefile=$(basename "$file")
          if [ "$basefile" != "flink-conf.yaml" ] && [ "$basefile" != "config.yaml" ]; then
            ln -s "$file" "$out/conf/$basefile"
          fi
        done
        cp "${flinkConf}" "$out/conf/flink-conf.yaml"
        cp "${flinkConf}" "$out/conf/config.yaml"
      '';
    };

  ## Create shell scripts with Flink configuration
  writeFlinkApplication =
    { pkgs, flinkConf, name, text, extraRuntimeInputs ? [ ], }:
    let
      flinkConfDir = createFlinkConfDir {
        pkgs = pkgs;
        flinkConf = flinkConf;
      };
    in pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = [
        pkgs.gnugrep
        pkgs.gnused
        pkgs.gawk
        (if pkgs.stdenv.isDarwin then pkgs.darwin.Libsystem else pkgs.glibc)
        (if pkgs.stdenv.isDarwin then pkgs.darwin.sudo else pkgs.su-exec)
        (if pkgs.stdenv.isDarwin then null else pkgs.gosu)
        pkgs.hostname
        pkgs.jemalloc
        pkgs.bash
        pkgs.findutils
        pkgs.util-linux
        pkgs.coreutils
        pkgs.openjdk11
      ] ++ extraRuntimeInputs;
      text = ''
        # Ensure FLINK_CONF_DIR is set
        if [ -z "''${FLINK_CONF_DIR:-}" ]; then
          export FLINK_CONF_DIR="${flinkConfDir}/conf"
          echo "FLINK_CONF_DIR set to $FLINK_CONF_DIR"
        else
          echo "FLINK_CONF_DIR already set to $FLINK_CONF_DIR"
        fi

        # Additional script logic
        ${text}
      '';
    };

  ## Create a Flink derivation
  mkFlinkDerivation = { pkgs, name, tag ? "latest", flinkConf ?
      pkgs.writeTextFile {
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
          taskmanager.numberOfTaskSlots: 3
          parallelism.default: 1
          jobmanager.execution.failover-strategy: region
          rest.address: localhost
          rest.port: 8081
          rest.bind-address: 0.0.0.0
          env.log.dir: /tmp/flink-logs
          env.java.home: ${pkgs.openjdk11}
          env.path: ${python-env}/bin/:$PATH
          python.path: ${python-env}/lib/python3.11/site-packages:${src}
          python.executable: ${python-env}/bin/python
          python.client.executable: ${python-env}/bin/python
          pipeline.jars: ${pkgs.fmf.flink-connector-kafka}
        '';
      }, python-env, src, flink-job-script ? "jobs/job.py"
    , additionalInstallPhase ? "", additionalPassThru ? { }
    , additionalFlinkJarSetup ? "", }:
    let
      flink-with-kafka-connector = pkgs.flink.overrideAttrs (oldAttrs: {
        installPhase = oldAttrs.installPhase + ''
          mkdir -p $out/opt/flink/lib
          cp -r ${pkgs.fmf.flink-connector-kafka} $out/opt/flink/lib/flink-sql-connector-kafka.jar
        '' ++ additionalFlinkJarSetup;
      });

      start-managers = writeFlinkApplication {
        inherit pkgs flinkConf;
        name = "start-managers";
        text = ''
          ${pkgs.flink}/opt/flink/bin/jobmanager.sh start &
          ${pkgs.flink}/opt/flink/bin/taskmanager.sh start &
        '';
      };
      stop-all = pkgs.writeShellScriptBin "stop-all" ''
        ${flink-with-kafka-connector}/opt/flink/bin/jobmanager.sh stop-all && ${pkgs.flink}/opt/flink/bin/taskmanager.sh stop-all
      '';
      sql-client = writeFlinkApplication {
        inherit pkgs flinkConf;
        name = "sql-client";
        text = ''
          export PYTHONPATH="${python-env}/lib/python3.11/site-packages:${src}"
          export PATH="${python-env}/bin/:$PATH"
          export PYFLINK_PYTHON="${python-env}/bin/python"
          export JAVA_HOME="${pkgs.openjdk11}"
          export FLINK_HOME="${pkgs.flink}/opt/flink"

          ${flink-with-kafka-connector}/opt/flink/bin/sql-client.sh -pyfs=${src} -j=${pkgs.fmf.flink-connector-kafka} -pyclientexec=${python-env}/bin/python "$@"
        '';
      };
      run-job = writeFlinkApplication {
        inherit pkgs flinkConf;
        name = "run-job";
        text = ''
          ${flink-with-kafka-connector}/bin/flink run \
            -py "$1" \
            -pyclientexec ${python-env}/bin/python \
            --jarfile ${pkgs.fmf.flink-connector-kafka}
        '';
      };
      job = pkgs.writeShellScriptBin "job" ''
        ${run-job}/bin/run-job ${src}/${flink-job-script}
      '';

      dev-scripts = lib.fmf.mkPythonDevScripts {
        inherit pkgs;
        project-drv = flink-job;
        python-env = python-env;
      };
      container = lib.fmf.buildFlinkContainer {
        inherit pkgs python-env name tag flink-job;
      };
      flink-job = pkgs.stdenv.mkDerivation {
        inherit name src;

        installPhase = ''
          mkdir -p "$out/src/tests"
          mkdir -p "$out/bin"
          mkdir -p "$out/opt/flink/usrlib"
          mkdir -p "$out/opt/flink/lib"
          mkdir -p "$out/conf"

          cp -r ${src}/* $out/src/
          cp -r ${flink-with-kafka-connector}/opt/flink $out/opt/
          ln -s ${pkgs.fmf.flink-connector-kafka} $out/opt/flink/lib/flink-kafka-connector.jar
          cp -r ${python-env}/bin/* $out/bin/
          cp ${stop-all}/bin/stop-all $out/bin/stop-all
          ${additionalInstallPhase}
        '';

        passthru = {
          python = python-env;
          bpython = dev-scripts.run-bpython;
          jupyter = dev-scripts.run-jupyter;
          test = dev-scripts.run-tests;
          stop-all = stop-all;
          run-job = run-job;
          job = job;
          start-managers = start-managers;
          flink = flink-with-kafka-connector;
          sql-client = sql-client;
          container = container;
        } // additionalPassThru;
      };
    in flink-job;

}
