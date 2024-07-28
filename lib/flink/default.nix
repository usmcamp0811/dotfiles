{ lib, inputs, snowfall-inputs, }: rec {
  ## Create a flink-conf-dir derivation
  ##
  ## This function generates a derivation that sets up the Flink configuration directory.
  ##
  ## Parameters:
  ## - `flinkConf`: The Flink configuration to be used.
  ##
  ## Example usage:
  ## ```nix
  ## createFlinkConfDir {
  ##   pkgs = import <nixpkgs> {};
  ##   flinkConf = ./flink-conf.yaml;
  ## }
  ## ```
  createFlinkConfDir = { pkgs, flinkConf }:
    pkgs.stdenv.mkDerivation {
      name = "flink-conf-drv";
      phases = [ "installPhase" ];
      installPhase = ''
        mkdir -p $out/conf
        for file in "${pkgs.flink}/opt/flink/conf"/*; do
            basefile=$(basename "$file")
            if [ "$basefile" != "flink-conf.yaml" ] && [ "$basefile" != "config.yaml" ]; then
                ln -s "$file" "$out/conf/$basefile"
            fi
        done
        cp ${flinkConf} $out/conf/flink-conf.yaml
        cp ${flinkConf} $out/conf/config.yaml
      '';
    };

  ## Create a set-flink-conf script
  ##
  ## This function generates a script that sets the FLINK_CONF_DIR environment variable.
  ##
  ## Parameters:
  ## - `flinkConfDir`: The directory containing Flink configuration files.
  ##
  ## Example usage:
  ## ```nix
  ## createSetFlinkConf {
  ##   pkgs = import <nixpkgs> {};
  ##   flinkConfDir = ./flink-conf-dir;
  ## }
  ## ```
  createSetFlinkConf = { pkgs, flinkConfDir }:
    pkgs.writeScript "set-flink-conf" ''
      if [ -z "$FLINK_CONF_DIR" ]; then
          export FLINK_CONF_DIR="${flinkConfDir}/conf";
          echo "FLINK_CONF_DIR set to $FLINK_CONF_DIR"
      else
          echo "FLINK_CONF_DIR already set to $FLINK_CONF_DIR"
      fi
    '';

  ## Create shell scripts with flink configuration
  ##
  ## This function generates shell scripts that set up the Flink configuration environment.
  ##
  ## Parameters:
  ## - `flinkConf`: The Flink configuration to be used.
  ## - `name`: The name of the script.
  ## - `script`: The script to be executed with the Flink configuration.
  ##
  ## Example usage:
  ## ```nix
  ## writeFlinkShellScriptBin {
  ##   pkgs = import <nixpkgs> {};
  ##   flinkConf = ./flink-conf.yaml;
  ##   name = "flink-job";
  ##   script = "flink run my-job.jar";
  ## }
  ## ```
  writeFlinkShellScriptBin = { pkgs, flinkConf, name, script, }:
    let
      flinkConfDir = createFlinkConfDir {
        pkgs = pkgs;
        flinkConf = flinkConf;
      };
      setFlinkConf = createSetFlinkConf {
        pkgs = pkgs;
        flinkConfDir = flinkConfDir;
      };
    in pkgs.writeShellScriptBin name ''
      source ${setFlinkConf}
      ${script}
    '';

  mkFlinkDerivation = { pkgs, name, flinkConf, python-env, src
    , flink-job-script ? "jobs/job.py", additionalInstallPhase ? ""
    , additionalPassThru ? { }, }:
    let
      start-managers = writeFlinkShellScriptBin {
        inherit pkgs flinkConf;
        name = "start-managers";
        script = ''
          ${pkgs.flink}/opt/flink/bin/jobmanager.sh start &
          ${pkgs.flink}/opt/flink/bin/taskmanager.sh start &
        '';
      };
      stop-all = pkgs.writeShellScriptBin "stop-all" ''
        ${pkgs.flink}/opt/flink/bin/jobmanager.sh stop-all && ${pkgs.flink}/opt/flink/bin/taskmanager.sh stop-all
      '';
      sql-client = writeFlinkShellScriptBin {
        inherit pkgs flinkConf;
        name = "sql-client";
        script = ''
          ${pkgs.flink}/opt/flink/bin/sql-client.sh $@
        '';
      };
      run-job = writeFlinkShellScriptBin {
        inherit pkgs flinkConf;
        name = "run-job";
        script = ''
          ${pkgs.flink}/bin/flink run \
            -py $1 \
            -pyclientexec python \
            --jarfile ${pkgs.campground.flink-connector-kafka}
        '';
      };
      job = pkgs.writeShellScriptBin "job" ''
        ${run-job}/bin/run-job ${src}/jobs/table-job.py
      '';
      dev-scripts = lib.mkPythonDevScripts {
        inherit pkgs;
        project-drv = flink-job;
        poetry-env = python-env;
      };
      container = lib.buildFlinkContainer {
        inherit pkgs python-env name;
        tag = "latest";
        flink-job = flink-job;
      };
      flink-job = pkgs.stdenv.mkDerivation {
        inherit name src;

        installPhase = ''
          mkdir -p $out/src/tests
          mkdir -p $out/src/tle_utils
          mkdir -p $out/bin
          mkdir -p $out/opt/flink/usrlib

          cp -r ${src}/* $out/src/
          cp -r ${pkgs.flink}/opt/flink $out/opt/
          cp -r ${python-env}/bin/* $out/bin/
          cp ${stop-all}/bin/stop-all $out/bin/stop-all
          cp -r ${flinkConf}/conf $out/
        '';

        passthru = {
          python = python-env;
          bpython = dev-scripts.run-bpython;
          jupyter = dev-scripts.run-jupyter;
          test = dev-scripts.test;
          stop-all = stop-all;
          # conf = flink-conf-dir;
          # run-table-job = table-job;
          # run-stream-job = stream-job;
          run-job = job;
          start-managers = start-managers;
          flink = pkgs.flink;
          sql-client = sql-client;
          container = container;
        };
      };
    in { inherit flink-job; };
}
