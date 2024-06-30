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
    "PythonCall"
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
  # python = pkgs.python311.withPackages
  #   (pythonPackages: with pythonPackages; [ jupyter qtconsole redfin numpy ]);
  startJupyterWithJulia = writeShellApplication {
    name = "start-jupyter-with-julia";
    runtimeInputs = [ python-env julia-env ];
    text = ''
      # Ensure Julia kernel is installed
      # Start Jupyter console with Julia kernel
      JULIA_VERSION="home-project-julia-$(julia -e 'println(string(VERSION.major) * "." * string(VERSION.minor))')"
      export PYTHON=${python-env}/bin/python 
      ${pkgs.poetry}/bin/poetry    
      ${julia-env}/bin/julia -e 'using Pkg; Pkg.build("PythonCall")'
      ${julia-env}/bin/julia -e 'using IJulia; installkernel("home-project-julia")' jupyter console --kernel "$JULIA_VERSION" "$@"
    '';
  };
in pkgs.mkShell {
  buildInputs = [
    pkgs.poetry
    pkgs.julia
    python-env
    # pkgs.python3
  ];

  shellHook = ''
    # Create Poetry environment
    # Activate Julia project
    julia --project=. -e 'using Pkg; Pkg.build("PyCall"); ENV["PYTHON"] = "$PYTHON"; Pkg.build("PyCall")'

    echo "Poetry environment and Julia project set up."
  '';
}
