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

  createJupyterApp = name: command:
    { pkgs, juliaEnv, kernelName }:
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = [ pkgs.openssl pkgs.jupyter-all juliaEnv ];
      text = ''
        #!${pkgs.runtimeShell}
        # Ensure Julia kernel is installed
        export PATH=${pkgs.jupyter-all}/bin:$PATH
        export LD_LIBRARY_PATH=${pkgs.openssl.out}/lib:$LD_LIBRARY_PATH
        export PYTHONPATH=${pkgs.jupyter-all}/lib/python3.11/site-packages:$PYTHONPATH
        JULIA_VERSION=$(${juliaEnv}/bin/julia -e 'println("${kernelName}-" * string(VERSION.major) * "." * string(VERSION.minor))')
        ${juliaEnv}/bin/julia -e "using IJulia; installkernel(\"${kernelName}\", julia=\`${juliaEnv}/bin/julia\`)"
        ${command} --kernel "$JULIA_VERSION" "$@"
      '';
    };
}
