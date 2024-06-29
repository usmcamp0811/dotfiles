{ lib, writeText, writeShellApplication, substituteAll, gum, inputs, pkgs
, hosts ? { }, ... }:
let
  inherit (lib) mapAttrsToList concatStringsSep;
  inherit (lib.campground) override-meta;
  julia-env = pkgs.julia.withPackages [ "IJulia" "CSV" "DataFrames" ];

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
      #!${pkgs.runtimeShell}
      # Ensure Julia kernel is installed
      # # Start Jupyter console with Julia kernel
      JULIA_VERSION="myjulia-$(julia -e 'println(string(VERSION.major) * "." * string(VERSION.minor))')"
      ${julia-env}/bin/julia -e 'using IJulia; installkernel("myjulia")'
      jupyter console --kernel "$JULIA_VERSION" "$@"
    '';
  };
in pkgs.stdenv.mkDerivation rec {
  pname = "my-jupyter-env";
  version = "1.0.0";

  src = ./.;
  installPhase = ''
    mkdir -p $out/bin
    cp -r ${python-env}/bin/* $out/bin/
  '';
  propogatedBuildInputs = [ python-env julia-env startJupyterWithJulia ];

  passthru = {
    jj = startJupyterWithJulia;
    python = python-env;
  };
}
