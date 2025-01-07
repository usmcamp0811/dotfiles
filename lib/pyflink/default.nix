{ lib, inputs }: rec {
  containerShadowSetup =
    { pkgs
    , user
    , uid
    , gid ? uid
    , homeDir ? "/home/${user}"
    , runtimeShell ? "/bin/bash"
    ,
    }:
      with pkgs; [
        (writeTextDir "etc/shadow" ''
          root:!x:::::::
          ${user}:!:::::::
        '')
        (writeTextDir "etc/passwd" ''
          root:x:0:0::/root:${runtimeShell}
          ${user}:x:${toString uid}:${toString gid}::${homeDir}:
        '')
        (writeTextDir "etc/group" ''
          root:x:0:
          ${user}:x:${toString gid}:
        '')
        (writeTextDir "etc/gshadow" ''
          root:x::
          ${user}:x::
        '')
      ];

  commonFlinkRuntimeInputs = pkgs: [
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
  ];

  getFlinkWithAdditionalJars = { pkgs, additionalJars ? [ ], }:
    pkgs.flink.overrideAttrs (oldAttrs: {
      installPhase = ''
        ${oldAttrs.installPhase}
        mkdir -p $out/opt/flink/lib
        ${builtins.concatStringsSep "\n" (map (jar: ''
          cp ${jar} $out/opt/flink/lib/$(basename ${jar})
        '') additionalJars)}
      '';
    });

  getFlinkKafkaConnector = pkgs:
    let
      kafka-jar = "flink-sql-connector-kafka";
      flink-version = builtins.concatStringsSep "."
        (pkgs.lib.take 2 (pkgs.lib.splitString "." pkgs.flink.version));
      jar-version = "3.2.0-${flink-version}";
      url =
        "https://repo.maven.apache.org/maven2/org/apache/flink/${kafka-jar}/${jar-version}/${kafka-jar}-${jar-version}.jar";
    in
    pkgs.fetchurl {
      inherit url;
      sha256 = builtins.trace "Expected SHA256:"
        "sha256-w+2jzSlcHN+x3Lrk4P0xjYLi3W8HMyjjDNefHZqZB3U=";
    };

  ## Create shell scripts with Flink configuration
  writeFlinkApplication =
    { pkgs, flinkConf, name, text, extraRuntimeInputs ? [ ], }:
    let
      flinkConfDir = pkgs.stdenv.mkDerivation {
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
    in
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = (commonFlinkRuntimeInputs pkgs) ++ extraRuntimeInputs;
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
  mkPyFlinkDerivation =
    { pkgs
    , name
    , tag ? "latest"
    , flinkConf ? null
    , src
    , pypkgs-build-requirements ? { }
    , flink-job-script ? "jobs/job.py"
    , additionalInstallPhase ? ""
    , additionalPassThru ? { }
    , additionalJars ? [ ]
    ,
    }:
    let
      # Extract the folder name (first element)
      # this is used in PYFILES so Flink can get submodules if you use them
      splitPath = lib.strings.split "/" flink-job-script;
      pyFolderName = builtins.head splitPath;

      flinkConf' =
        if flinkConf == null then
          pkgs.writeTextFile
            {
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
                env.path: ${python-env.python}/bin/:$PATH
                python.path: ${python-env.python}/lib/python${pythonVersion}/site-packages:${src}
                python.executable: ${python-env.python}/bin/python
                python.client.executable: ${python-env.python}/bin/python
                pipeline.jars: ${getFlinkKafkaConnector pkgs}
              '';
            }
        else
          flinkConf;

      flink-with-kafka-connector = getFlinkWithAdditionalJars {
        inherit pkgs;
        additionalJars = additionalJars ++ [ (getFlinkKafkaConnector pkgs) ];
      };

      pythonVersion = builtins.substring 0 4 python-env.python.python.version;

      python-env = lib.campground.mkPythonDerivation {
        inherit pkgs name src pypkgs-build-requirements;
      };

      start-managers = writeFlinkApplication {
        inherit pkgs;
        flinkConf = flinkConf';
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
        inherit pkgs;
        flinkConf = flinkConf';
        name = "sql-client";
        text = ''
          export PYTHONPATH=${python-env.python}/lib/python${pythonVersion}/site-packages:${src}/${pyFolderName}:${src}
          export PATH="${python-env.python}/bin/:$PATH"
          export PYFLINK_PYTHON="${python-env.python}/bin/python"
          export JAVA_HOME="${pkgs.openjdk11}"
          export FLINK_HOME="${flink-with-kafka-connector}/opt/flink"

          echo "PYFILES: ${src}/${pyFolderName}"
          echo "PYTHONPATH: $PYTHONPATH"

          # Execute the sql-client.sh with the additional JARs
          ${flink-with-kafka-connector}/opt/flink/bin/sql-client.sh "$@" \
            -j=${getFlinkKafkaConnector pkgs} ${
              builtins.concatStringsSep " "
              (map (jar: "-j=${jar}") additionalJars)
            } -pyfs=${src} -pyclientexec=${python-env}/bin/python
        '';
      };

      run-job = writeFlinkApplication {
        inherit pkgs;
        flinkConf = flinkConf';
        name = "run-job";
        text = ''
          PYFILES="${src},${src}/${pyFolderName},${src}/${flink-job-script}"
          ${flink-with-kafka-connector}/bin/flink run \
            -py "$1" \
            -pyclientexec ${python-env.python}/bin/python \
            --pyFiles="$PYFILES" \
            --jarfile ${getFlinkKafkaConnector pkgs} ${
              builtins.concatStringsSep " "
              (map (jar: "--jarfile=${jar}") additionalJars)
            } 
        '';
      };

      job = pkgs.writeShellScriptBin "job" ''
        ${run-job}/bin/run-job ${src}/${flink-job-script}
      '';

      docker-entrypoint = pkgs.fetchurl {
        url =
          "https://raw.githubusercontent.com/apache/flink-docker/master/1.19/scala_2.12-java11-ubuntu/docker-entrypoint.sh";
        sha256 = "sha256-P6nhTzKGgrsGKppaWMWDlQ3JzSjEW+ECJVFqRtTeC/k=";
      };

      container = pkgs.dockerTools.buildLayeredImage {
        name = name;
        tag = tag;
        contents = commonFlinkRuntimeInputs pkgs
          ++ [ python-env.python flink-job ] ++ containerShadowSetup {
          inherit pkgs;
          uid = 9999;
          gid = 9999;
          user = "flink";
          homeDir = "/opt/flink";
        };
        config = {
          Entrypoint = [ "/docker-entrypoint.sh" ];
          Env = [
            "PYFILES=${src},${src}/${pyFolderName}"
            "PYTHONPATH=${python-env.python}/lib/python${pythonVersion}/site-packages:${src}:${src}/${pyFolderName}"
            "PYFLINK_PYTHON=${python-env.python}/bin/python"
            "JAVA_HOME=${pkgs.openjdk11}"
            "FLINK_HOME=/opt/flink"
            "FLINK_BIN_DIR=/opt/flink/bin"
            "PATH=/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/opt/flink/bin"
            "CLASSPATH=/opt/flink/lib"
            "FLINK_CONF_DIR=/opt/flink/conf"
          ];
        };

        fakeRootCommands = ''
          mkdir -p ./tmp ./usr/lib ./usr/bin ./opt/flink/usrlib
          chmod -R 777 ./tmp
          cp -r ${pkgs.flink}/opt/flink ./opt/
          cp  ${pkgs.flink}/bin/flink ./bin/
          cp -r ${
            getFlinkKafkaConnector pkgs
          } ./opt/flink/lib/flink-sql-connector-kafka.jar
          cp ${docker-entrypoint} ./docker-entrypoint.sh
          cp -r ${pkgs.coreutils}/bin/* ./usr/bin/
          chmod +x ./docker-entrypoint.sh
          chmod 777 ./docker-entrypoint.sh
          chmod -R 777 ./opt/flink
        '';
      };
      flink-job = pkgs.stdenv.mkDerivation {
        inherit name src;

        installPhase = ''
          mkdir -p "$out/src/tests" "$out/bin" "$out/opt/flink/usrlib" "$out/opt/flink/lib" "$out/conf"
          cp -r ${src}/* $out/src/
          cp -r ${flink-with-kafka-connector}/opt/flink $out/opt/
          ln -s ${
            getFlinkKafkaConnector pkgs
          } $out/opt/flink/lib/flink-kafka-connector.jar
          # Copy all additional JARs to $out/opt/flink/lib
          cp -r ${python-env.python}/bin/* $out/bin/
          cp ${stop-all}/bin/stop-all $out/bin/stop-all
          ${additionalInstallPhase}
        '';

        passthru = {
          python = python-env.python;
          bpython = python-env.bpython;
          jupyter = python-env.jupyter;
          test = python-env.test;
          stop-all = stop-all;
          flink-run = run-job;
          run-job = job;
          start-managers = start-managers;
          flink = flink-with-kafka-connector;
          sql-client = sql-client;
          container = container;
          push-img = lib.campground.pushDockerImage {
            inherit pkgs;
            dockerImage = container;
          };
        } // additionalPassThru;
      };
    in
    flink-job;

}
