{ lib, writeText, writeShellApplication, substituteAll, gum, inputs, pkgs
, hosts ? { }, ... }:
let
  inherit (lib) mapAttrsToList concatStringsSep;
  inherit (lib.campground) override-meta;
  src = ./.;
  julia-env = pkgs.julia.withPackages.override { extraLibs = [ python-env ]; } [
    "IJulia"
    "CSV"
    "DataFrames"
    "PyCall"
  ];

  pypkgs-build-requirements = { redfin = [ "setuptools" ]; };

  p2n-overrides = pkgs.poetry2nix.defaultPoetryOverrides.extend (self: super:
    builtins.mapAttrs (package: build-requirements:
      (builtins.getAttr package super).overridePythonAttrs (old: {
        buildInputs = (old.buildInputs or [ ]) ++ (builtins.map (pkg:
          if builtins.isString pkg then builtins.getAttr pkg super else pkg)
          build-requirements);
      })) pypkgs-build-requirements);

  python-env = pkgs.poetry2nix.mkPoetryEnv {
    projectDir = ./.;
    overrides = p2n-overrides;
    python = pkgs.python311;
  };
  startJupyterWithJulia = writeShellApplication {
    name = "start-jupyter-with-julia";
    runtimeInputs = [ python-env julia-env ];
    text = ''
      # Ensure Julia kernel is installed
      # Start Jupyter console with Julia kernel
      export KERNEL_NAME="home-project-julia"
      JULIA_VERSION="$KERNEL_NAME-$(julia -e 'println(string(VERSION.major) * "." * string(VERSION.minor))')"
      export PYTHONPATH="${python-env}/lib/python3.11/site-packages:${python-env}/lib/site-packages"
      ${julia-env}/bin/julia -e 'using IJulia; installkernel(ENV["KERNEL_NAME"])' 
      ${python-env}/bin/jupyter console --kernel "$JULIA_VERSION" "$@"
    '';
  };
in pkgs.mkShell {
  buildInputs = [ pkgs.poetry julia-env python-env startJupyterWithJulia ];
  env = {
    PYTHONPATH =
      "${python-env}/lib/python3.11/site-packages:${python-env}/lib/site-packages";
  };
  shellHook = ''
    echo "Poetry environment and Julia project set up."
  '';
}
