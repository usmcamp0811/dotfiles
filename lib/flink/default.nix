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
  createFlinkConfDir = { pkgs, flinkConf, }:
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
  createSetFlinkConf = { pkgs, flinkConfDir, }:
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
}
