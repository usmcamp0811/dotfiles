{ lib, writeText, writeShellApplication, substituteAll, gum, inputs, pkgs
, hosts ? { }, ... }:
let
  inherit (lib) mapAttrsToList concatStringsSep;
  inherit (lib.campground) override-meta;
  julia-env = pkgs.julia.withPackages.override {
    extraLibs =
      [ pkgs.libxcrypt pkgs.libxcrypt-legacy pkgs.openssl pkgs.cyrus_sasl ];
  } [
    "FileIO"
    "JLD2"
    "DataFrames"
    "MLJ"
    "PyCall"
    "IJulia"
    "CSV"
    "LanguageServer"
  ];
  startJupyterWithJulia = writeShellApplication {
    name = "julia-console";
    runtimeInputs = [ pkgs.openssl pkgs.jupyter-all julia-env ];
    text = ''
      #!${pkgs.runtimeShell}
      # Ensure Julia kernel is installed
      export PATH=${pkgs.jupyter-all}/bin:$PATH
      export LD_LIBRARY_PATH=${pkgs.openssl.out}/lib:$LD_LIBRARY_PATH
      export PYTHONPATH=${pkgs.jupyter-all}/lib/python3.11/site-packages
      JULIA_VERSION=$(${julia-env}/bin/julia -e 'println("campground-julia-" * string(VERSION.major) * "." * string(VERSION.minor))')
      ${julia-env}/bin/julia -e "using IJulia; installkernel(\"campground-julia\", julia=\`${julia-env}/bin/julia\`)"
      ${pkgs.jupyter-all}/bin/jupyter console --kernel "$JULIA_VERSION" "$@"
    '';
  };
  startQtJupyterWithJulia = writeShellApplication {
    name = "julia-qtconsole";
    runtimeInputs = [ pkgs.openssl pkgs.jupyter-all julia-env ];
    text = ''
      #!${pkgs.runtimeShell}
      # Ensure Julia kernel is installed
      # # Start Jupyter console with Julia kernel
      export PATH=${pkgs.jupyter-all}/bin:$PATH
      export LD_LIBRARY_PATH=${pkgs.openssl.out}/lib:$LD_LIBRARY_PATH
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
