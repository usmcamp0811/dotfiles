{ lib, ... }:
with lib.fmf;
let
  /* *
     Function to build a Flink container image that is compatible with
     Kubernetes Flink Operator.

     @param pkgs - A set of Nix packages.
     @param name - The name of the Docker image.
     @param tag - The tag of the Docker image.
     @param python-env - The Python environment to include in the image.
     @param flink-job - A Derivation containing the PyFlink Job source.

     @return A Docker container image.
  */
  buildFlinkContainer = { pkgs, name, tag, python-env, flink-job, }:
    let

      docker-entrypoint = pkgs.fetchurl {
        url =
          "https://raw.githubusercontent.com/apache/flink-docker/master/1.19/scala_2.12-java11-ubuntu/docker-entrypoint.sh";
        sha256 = "sha256-P6nhTzKGgrsGKppaWMWDlQ3JzSjEW+ECJVFqRtTeC/k=";
      };

      container = pkgs.dockerTools.buildLayeredImage {
        name = name;
        tag = tag;
        contents = [
          pkgs.gnugrep
          pkgs.gnused
          pkgs.gawk
          pkgs.glibc
          pkgs.hostname
          pkgs.su-exec
          pkgs.gosu
          pkgs.jemalloc
          python-env
          pkgs.bash
          flink-job
          pkgs.findutils
          pkgs.bash
          pkgs.util-linux
          pkgs.coreutils
          pkgs.openjdk11
        ] ++ containerShadowSetup {
          inherit pkgs;
          uid = 9999;
          gid = 9999;
          user = "flink";
          homeDir = "/opt/flink";
        };
        config = {
          Entrypoint = [ "/docker-entrypoint.sh" ];
          Env = [
            "PYTHONPATH=${python-env}/lib/python3.11/site-packages:${flink-job.src}"
            "PYFLINK_PYTHON=${python-env}/bin/python"
            "JAVA_HOME=${pkgs.openjdk11}"
            "FLINK_HOME=/opt/flink"
            "FLINK_BIN_DIR=/opt/flink/bin"
            "PATH=/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/opt/flink/bin"
            "CLASSPATH=/opt/flink/lib"
            "FLINK_CONF_DIR=/opt/flink/conf"
          ];
        };
        fakeRootCommands = ''
          mkdir -p ./tmp
          mkdir -p ./usr/lib
          mkdir -p ./usr/bin
          mkdir -p ./opt/flink/usrlib
          chmod -R 777 ./tmp
          cp -r ${pkgs.flink}/opt/flink ./opt/
          cp  ${pkgs.flink}/bin/flink ./bin/
          cp -r ${pkgs.fmf.flink-connector-kafka} ./opt/flink/lib/flink-sql-connector-kafka.jar
          cp ${docker-entrypoint} ./docker-entrypoint.sh
          cp -r ${pkgs.coreutils}/bin/* ./usr/bin/
          chmod +x ./docker-entrypoint.sh
          chmod 777 ./docker-entrypoint.sh
          chmod -R 777 ./opt/flink
        '';
      };
    in container;
in { inherit buildFlinkContainer; }
