{
  lib,
  writeText,
  writeShellApplication,
  substituteAll,
  gum,
  inputs,
  pkgs,
  hosts ? { },
  ...
}:
with lib;
with lib.campground;
let
  src = ./.;
  julia-env = pkgs.julia.withPackages.override { extraLibs = [ python-env ]; } [
    "IJulia"
    "CSV"
    "DataFrames"
    "PyCall"
  ];

  # builtins.mapAttrs (package: build-requirements:
  #   (builtins.getAttr package super).overridePythonAttrs (old: {
  #     buildInputs = (old.buildInputs or [ ]) ++ (builtins.map (pkg:
  #       if builtins.isString pkg then builtins.getAttr pkg super else pkg)
  #       build-requirements);
  #   })) pypkgs-build-requirements);

  python-env = mkPythonDerivation {
    inherit pkgs;
    src = ./.;
    name = "redfin_search";
    pypkgs-build-requirements = {
      redfin = [ "setuptools" ];
    };
  };

  startJupyterWithJulia = writeShellApplication {
    name = "start-jupyter-with-julia";
    runtimeInputs = [
      python-env
      julia-env
    ];
    text = ''
      # Ensure Julia kernel is installed
      # Start Jupyter console with Julia kernel
      export KERNEL_NAME="home-project-julia"
      JULIA_VERSION="$KERNEL_NAME-$(julia -e 'println(string(VERSION.major) * "." * string(VERSION.minor))')"
      export PYTHONPATH="${python-env.python}/lib/python3.11/site-packages:${python-env}/lib/site-packages"
      ${julia-env}/bin/julia -e 'using IJulia; installkernel(ENV["KERNEL_NAME"])' 
      ${python-env.python}/bin/jupyter console --kernel "$JULIA_VERSION" "$@"
    '';
  };
in
pkgs.mkShell {
  buildInputs = [
    pkgs.poetry
    julia-env
    python-env.python
    startJupyterWithJulia
  ];
  env = {
    PYTHONPATH = "${python-env.python}/lib/python3.11/site-packages:${python-env}/lib/site-packages";
  };
  shellHook = ''
    echo "Poetry environment and Julia project set up."
  '';
}
