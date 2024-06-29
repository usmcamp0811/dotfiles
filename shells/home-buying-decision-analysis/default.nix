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

      ${julia-env}/bin/julia -e '
      using Pkg;
      ENV["PYTHON"] = "${python-env}/bin/python";
      Pkg.build("PyCall");
      using PyCall;
      try
          @pyimport redfin
      catch
          println("Error: The Python package redfin could not be imported.")
      end
      using IJulia;
      installkernel("home-project-julia")'
      jupyter console --kernel "$JULIA_VERSION" "$@"
    '';
  };
in pkgs.mkShell {
  propogatedBuildInputs = [ python-env julia-env startJupyterWithJulia ];
  shellHook = ''
    echo -e "\e[32m+-----------------------------------------------------------+\e[0m"
    echo -e "\e[32m|🏕️  Welcome to the Campground                              |\e[0m"
    echo -e "\e[32m+-----------------------------------------------------------+\e[0m"
    echo -e "\e[34m| run-flask-app  \e[0m - \e[37mTo start Flask with uWSGI               |\e[0m"
    echo -e "\e[34m| dev-flask-app  \e[0m - \e[37mTo run the Flask dev server.            |\e[0m"
    echo -e "\e[32m+-----------------------------------------------------------+\e[0m"

    # Additional setup can go here
  '';
}
