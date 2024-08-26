{ lib, inputs, ... }: rec {
  mkPythonDerivation = { pkgs, name, src, phases ? [ "installPhase" ]
    , pypkgs-build-requirements ? { }, container ? { }, buildPhase ? ""
    , installPhase ? "", meta ? { }, }:
    let
      defaultContainer = {
        tag = "latest";
        contents = [ python-env ];
        config = { Entrypoint = [ "${python-env}/bin/python" ]; };
      };
      finalContainer = defaultContainer // container;

      p2n-overrides = pkgs.poetry2nix.defaultPoetryOverrides.extend
        (self: super:
          builtins.mapAttrs (package: build-requirements:
            let
              override = super.${package}.overridePythonAttrs (oldAttrs: {
                buildInputs = (oldAttrs.buildInputs or [ ])
                  ++ (builtins.map (req: super.${req}) build-requirements);
              });
            in override) pypkgs-build-requirements);

      python-env = pkgs.poetry2nix.mkPoetryEnv {
        projectDir = src;
        python = pkgs.python311;
        overrides = p2n-overrides;
        preferWheels = true;
      };

      extended-python-env =
        python-env.withPackages (ps: with ps; [ bpython pytest ipykernel ]);

      pythonVersion = builtins.substring 0 4
        python-env.python.version; # Extract the major and minor version (e.g., "3.11")
      jupyterPythonVersion = builtins.substring 0 4
        pkgs.jupyter-all.python.version; # Extract the major and minor version (e.g., "3.11")

      run-bpython = pkgs.writeShellScriptBin "run-bpython" ''
        export PYTHONPATH=${python-env}/lib/python${pythonVersion}/site-packages:${src}
        ${extended-python-env}/bin/bpython "$@"
      '';

      run-jupyter = pkgs.writeShellScriptBin "run-jupyter" ''
        export PYTHONPATH=${pkgs.jupyter-all}/lib/python${jupyterPythonVersion}/site-packages:${python-env}/lib/python${pythonVersion}/site-packages:${src}
        ${pkgs.jupyter-all}/bin/jupyter console "$@"
      '';

      run-tests = pkgs.writeShellScriptBin "run-tests" ''
        export PYTHONPATH="${python-env}/lib/python${
          builtins.substring 0 4 python-env.python.version
        }/site-packages:${src}"
        ${extended-python-env}/bin/pytest ${src}/tests/ "$@"
      '';

      container = pkgs.dockerTools.buildLayeredImage {
        name = pyDerivation.name;
        inherit (finalContainer) tag contents config;
      };

      pyDerivation = pkgs.stdenv.mkDerivation {
        name = name;
        src = src;
        phases = phases;
        buildPhase = buildPhase;
        installPhase = ''
          mkdir -p $out/src
          mkdir -p $out/bin
          cp -r $src/* $out/src
          cp ${run-tests}/bin/run-tests $out/src/run-tests
        '' + installPhase;
        passthru = {
          python = python-env;
          bpython = run-bpython;
          jupyter = run-jupyter;
          test = run-tests;
          container = container;
        };
        meta = meta;
      };
    in pyDerivation;

}
