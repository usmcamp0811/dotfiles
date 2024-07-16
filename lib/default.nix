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
}
