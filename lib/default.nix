{ lib, inputs, snowfall-inputs, }: rec {
  ## Override a package's metadata
  ##
  ## ```nix
  ## let
  ##  new-meta = {
  ##    description = "My new description";
  ##  };
  ## in
  ##  lib.override-meta new-meta pkgs.hello
  ## ```
  ##
  #@ Attrs -> Package -> Package
  override-meta = meta: package:
    package.overrideAttrs (attrs: { meta = (attrs.meta or { }) // meta; });

  ## Create a Julia Jupyter Console
  ##
  ## This function generates a shell script that sets up the environment and runs a specified command with the Jupyter kernel.
  ##
  ## Parameters:
  ## - `name`: The name of the application.
  ## - `command`: The command to be executed within the Jupyter environment.
  ## - `pkgs`: The Nixpkgs package set.
  ## - `juliaEnv`: The Julia environment to be used.
  ## - `kernelName`: The name to be used for the Julia kernel.
  ##
  ## Example usage:
  ## ```nix
  ## createJuliaConsole "my-jupyter-app" "jupyter notebook" {
  ##   pkgs = import <nixpkgs> {};
  ##   juliaEnv = pkgs.julia.withPackages (ps: with ps; [ IJulia ]);
  ##   kernelName = "my-kernel";
  ## }
  ## ```
  createJuliaConsole = name: command:
    { pkgs, juliaEnv, kernelName }:
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = [ pkgs.openssl pkgs.jupyter-all juliaEnv ];
      text = ''
        #!${pkgs.runtimeShell}
        # Ensure Julia kernel is installed
        export PATH=${pkgs.jupyter-all}/bin:$PATH
        export LD_LIBRARY_PATH=${pkgs.openssl.out}/lib:$LD_LIBRARY_PATH
        export PYTHONPATH=${pkgs.jupyter-all}/lib/python3.11/site-packages
        JULIA_VERSION=$(${juliaEnv}/bin/julia -e 'println("${kernelName}-" * string(VERSION.major) * "." * string(VERSION.minor))')
        ${juliaEnv}/bin/julia -e "using IJulia; installkernel(\"${kernelName}\", julia=\`${juliaEnv}/bin/julia\`)"
        ${command} --kernel "$JULIA_VERSION" "$@"
      '';
    };

  ## Creates a set of shell scripts for interacting with a Python environment.
  ##
  ## @param python-env The Python environment to use for running Python scripts.
  ## @param src The source code directory to set in PYTHONPATH.
  ##
  ## @returns A set of shell scripts:
  ##   - run-tests: Runs pytest on the tests directory.
  ##   - run-bpython: Starts a bpython REPL with the source code in PYTHONPATH.
  ##   - run-jupyter: Starts a Jupyter console with the source code in PYTHONPATH.
  mkPythonDevScripts = { pkgs, python-env, src }:
    let
      # Extend the given python environment with additional packages
      extended-python-env = python-env.withPackages
        (ps: with ps; [ bpython pytest jupyter ipykernel ]);
    in {
      run-tests = pkgs.writeShellScriptBin "run-tests" ''
        # Resolves the symlink to find the actual path of the script
        SCRIPT=$(readlink -f "$0" || realpath "$0")
        SCRIPT_DIR=$(dirname "$SCRIPT")

        # Adjusted to ensure it works regardless of where it's called from
        BASE_DIR=$(dirname "$SCRIPT_DIR")
        ${extended-python-env}/bin/pytest $SCRIPT_DIR/tests/ "$@"
      '';

      run-bpython = pkgs.writeShellScriptBin "run-bpython" ''
        export PYTHONPATH=${src}:$PYTHONPATH
        ${extended-python-env}/bin/bpython "$@"
      '';

      run-jupyter = pkgs.writeShellScriptBin "run-jupyter" ''
        export PYTHONPATH=${src}:${pkgs.jupyter-all}/lib/python3.11/site-packages
        ${pkgs.jupyter-all}/bin/jupyter console "$@"
      '';

      test-access-window-flink-job = pkgs.stdenv.mkDerivation {
        name = "test-access-window-flink-job";
        src = src;
        phases = [ "installPhase" ];
        propagatedBuildInputs = [ python-env ];
        installPhase = ''
          mkdir -p $out/bin
          ln -s ${src}/src/run-tests $out/bin/run-tests
        '';
        meta = {
          description = "Tests for TLE Utils";
          mainProgram = "run-tests";
        };
      };
    };
}
