{ lib, writeText, writeShellApplication, substituteAll, gum, inputs, pkgs
, hosts ? { }, ... }:
let
  inherit (lib) mapAttrsToList concatStringsSep;
  inherit (lib.campground) override-meta;
  julia-env = pkgs.julia.withPackages [
    "FileIO"
    "JLD2"
    "DataFrames"
    "MLJ"
    "PyCall"
    "IJulia"
    "CSV"
  ];
  startJupyterWithJulia = writeShellApplication {
    name = "julia-console";
    runtimeInputs = [ pkgs.jupyter-all julia-env ];
    text = ''
      #!${pkgs.runtimeShell}
      # Ensure Julia kernel is installed
      export LD_LIBRARY_PATH=${pkgs.openssl.out}/lib:$LD_LIBRARY_PATH
      export PATH=${pkgs.jupyter-all}/bin:$PATH
      export PYTHONPATH=${pkgs.jupyter-all}/lib/python3.11/site-packages:$PYTHONPATH
      JULIA_VERSION=$(${julia-env}/bin/julia -e 'println("campground-julia-" * string(VERSION.major) * "." * string(VERSION.minor))')
      ${julia-env}/bin/julia -e "using IJulia; installkernel(\"campground-julia\", julia=\`${julia-env}/bin/julia\`)"
      ${pkgs.jupyter-all}/bin/jupyter console --kernel "$JULIA_VERSION" "$@"
    '';
  };
  startQtJupyterWithJulia = writeShellApplication {
    name = "julia-qtconsole";
    runtimeInputs = [ pkgs.jupyter-all julia-env ];
    text = ''
      #!${pkgs.runtimeShell}
      # Ensure Julia kernel is installed
      # # Start Jupyter console with Julia kernel
      export LD_LIBRARY_PATH=${pkgs.openssl.out}/lib:$LD_LIBRARY_PATH
      export PATH=${pkgs.jupyter-all}/bin:$PATH
      export PYTHONPATH=${pkgs.jupyter-all}/lib/python3.11/site-packages:$PYTHONPATH
      JULIA_VERSION=$(${julia-env}/bin/julia -e 'println("campground-julia-" * string(VERSION.major) * "." * string(VERSION.minor))')
      ${julia-env}/bin/julia -e "using IJulia; installkernel(\"campground-julia\", julia=\`${julia-env}/bin/julia\`)"
      ${pkgs.jupyter-all}/bin/jupyter qtconsole --kernel "$JULIA_VERSION" "$@"
    '';
  };
in pkgs.stdenv.mkDerivation rec {
  pname = "julia";
  version = pkgs.julia.version;
  src = ./.;

  buildInputs = [ pkgs.jupyter-all julia-env pkgs.openssl ];

  installPhase = ''
    mkdir -p $out/bin
    cp -r ${julia-env}/bin/julia $out/bin/julia
    cp -r ${startJupyterWithJulia}/bin/* $out/bin/
    cp -r ${startQtJupyterWithJulia}/bin/* $out/bin/
  '';
  mainProgram = "julia";

  passthru = {
    jupyter-qtconsole = startQtJupyterWithJulia;
    jupyter-console = startJupyterWithJulia;
  };
}
