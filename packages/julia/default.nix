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
  python = pkgs.python311.withPackages (pythonPackages:
    with pythonPackages; [
      ipython
      jupyter
      qtconsole
      jupyter_console
      ipykernel
    ]);
  startJupyterWithJulia = writeShellApplication {
    name = "julia-console";
    runtimeInputs = [ python julia-env pkgs.jupyter ];
    text = ''
      #!${pkgs.runtimeShell}
      # Ensure Julia kernel is installed
      # # Start Jupyter console with Julia kernel
      export LD_LIBRARY_PATH=${pkgs.openssl.out}/lib:$LD_LIBRARY_PATH
      export PYTHONPATH=$PWD/${python}/${python.sitePackages}/:$PYTHONPATH
      JULIA_VERSION="campground-julia-$(${julia-env}/bin/julia  -e 'println(string(VERSION.major) * "." * string(VERSION.minor))')"
      ${julia-env}/bin/julia -e 'using IJulia; installkernel("campground-julia")'
      ${python}/bin/jupyter console --kernel "$JULIA_VERSION" "$@"
    '';
  };
  startQtJupyterWithJulia = writeShellApplication {
    name = "julia-qtconsole";
    runtimeInputs = [ python julia-env ];
    text = ''
      #!${pkgs.runtimeShell}
      # Ensure Julia kernel is installed
      # # Start Jupyter console with Julia kernel
      export LD_LIBRARY_PATH=${pkgs.openssl.out}/lib:$LD_LIBRARY_PATH
      JULIA_VERSION="campground-julia-$(${julia-env}/bin/julia -e 'println(string(VERSION.major) * "." * string(VERSION.minor))')"
      ${julia-env}/bin/julia -e 'using IJulia; installkernel("campground-julia")'
      ${python}/bin/jupyter qtconsole --kernel "$JULIA_VERSION" "$@"
    '';
  };
in pkgs.stdenv.mkDerivation rec {
  pname = "julia";
  version = pkgs.julia.version;
  src = ./.;

  buildInputs = [ python julia-env pkgs.openssl ];

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
    python = python;
  };
}
