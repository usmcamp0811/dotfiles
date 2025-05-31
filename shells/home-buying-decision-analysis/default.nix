{ lib
, writeText
, writeShellApplication
, gum
, inputs
, pkgs
, hosts ? { }
, ...
}:
with lib;
with lib.campground; let
  src = ./.;
  julia-env = pkgs.julia.withPackages.override { extraLibs = [ python-env ]; } [
    "IJulia"
    "CSV"
    "DataFrames"
    "PyCall"
    "Missings"
    "OpenStreetMapX"
    "HTTP"
    "JSON"
  ];

  startJupyterWithJulia =
    createJuliaConsole "julia-console" "${pkgs.jupyter-all}/bin/jupyter console"
      {
        pkgs = pkgs;
        juliaEnv = julia-env;
        kernelName = "homeSearch";
        pythonPath = "${python-env.python}/lib/python3.11/site-packages:${python-env}/lib/site-packages";
      };
  startQtJupyterWithJulia =
    createJuliaConsole "julia-qtconsole" "${pkgs.jupyter-all}/bin/jupyter qtconsole"
      {
        pkgs = pkgs;
        juliaEnv = julia-env;
        kernelName = "homeSearch";
      };

  python-env = mkPythonDerivation {
    inherit pkgs;
    src = ./.;
    name = "redfin_search";
    pypkgs-build-requirements = {
      redfin = [ "setuptools" ];
    };
  };
in
pkgs.mkShell {
  buildInputs = [
    pkgs.poetry
    julia-env
    python-env.python
    python-env.bpython
    startQtJupyterWithJulia
    startJupyterWithJulia
  ];
  env = {
    PYTHONPATH = "${python-env.python}/lib/python3.11/site-packages:${python-env.python}/lib/site-packages";
  };
  shellHook = ''
    echo "Poetry environment and Julia project set up."
  '';
}
