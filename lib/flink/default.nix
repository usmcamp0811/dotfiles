{ pkgs, lib, inputs, snowfall-inputs, }: rec {
  # Function to create the flink-conf-dir derivation
  createFlinkConfDir = flinkConf:
    pkgs.stdenv.mkDerivation {
      name = "flink-conf-drv";
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
        cp ${flinkConf} $out/conf/flink-conf.yaml
        cp ${flinkConf} $out/conf/config.yaml
      '';
    };

  # Function to create the set-flink-conf script
  createSetFlinkConf = flinkConfDir:
    pkgs.writeScript "set-flink-conf" ''
      # Check if FLINK_CONF_DIR is unset or empty
      if [ -z "$FLINK_CONF_DIR" ]; then
          export FLINK_CONF_DIR="${flinkConfDir}/conf";
          echo "FLINK_CONF_DIR set to $FLINK_CONF_DIR"
      else
          echo "FLINK_CONF_DIR already set to $FLINK_CONF_DIR"
      fi
    '';

  # General function to create shell scripts with flink configuration
  writeFlinkShellScriptBin = flinkConf: name: script:
    let
      flinkConfDir = createFlinkConfDir flinkConf;
      setFlinkConf = createSetFlinkConf flinkConfDir;
    in pkgs.writeShellScriptBin name ''
      source ${setFlinkConf}
      ${script}
    '';
}
