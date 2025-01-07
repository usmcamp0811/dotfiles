{ lib, inputs, ... }: rec {

  mkPythonDerivation =
    { pkgs
    , name
    , src
    , phases ? [ "installPhase" ]
    , pypkgs-build-requirements ? { }
    , container ? { }
    , buildPhase ? ""
    , installPhase ? ""
    , meta ? { }
    , python ? pkgs.python311
    , extraPackages ? (ps: [ ])
    , p2n-overrides ? (self: super:
        builtins.mapAttrs
          (package: build-requirements:
            let
              override = super.${package}.overridePythonAttrs (oldAttrs: {
                buildInputs = (oldAttrs.buildInputs or [ ])
                  ++ (builtins.map (req: super.${req}) build-requirements);
              });
            in
            override)
          pypkgs-build-requirements)
    ,
    }:
    let
      defaultContainer = {
        name = name;
        tag = "latest";
        contents = [ python-env ];
        config = { Entrypoint = [ "${python-env}/bin/python" ]; };
      };
      finalContainer = defaultContainer // container;
      final-p2n-overrides =
        pkgs.poetry2nix.defaultPoetryOverrides.extend p2n-overrides;
      # p2n-overrides = pkgs.poetry2nix.defaultPoetryOverrides.extend (
      #   self: super:
      #   builtins.mapAttrs (
      #     package: build-requirements:
      #     let
      #       override = super.${package}.overridePythonAttrs (oldAttrs: {
      #         buildInputs =
      #           (oldAttrs.buildInputs or [ ]) ++ (builtins.map (req: super.${req}) build-requirements);
      #       });
      #     in
      #     override
      #   ) pypkgs-build-requirements
      # );

      pyprojectExists = builtins.pathExists "${src}/pyproject.toml";

      # If pyproject.toml exists, use poetry2nix, otherwise use customPythonEnv
      python-env =
        if pyprojectExists then
          pkgs.poetry2nix.mkPoetryEnv
            {
              inherit extraPackages;
              projectDir = src;
              python = python;
              overrides = final-p2n-overrides;
              preferWheels = true;
            }
        else
          python;

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

      container-img = pkgs.dockerTools.buildLayeredImage finalContainer;

      pyDerivation = pkgs.stdenv.mkDerivation {
        name = name;
        src = src;
        phases = phases;
        buildPhase = buildPhase;
        installPhase =
          if installPhase == null || installPhase == "" then ''
            mkdir -p $out/src
            mkdir -p $out/bin
            if [ -d "$src" ]; then
              cp -r $src/* $out/src
            elif [ -f "$src" ]; then
              cp $src $out/src/
            else
              echo "Error: $src is not a valid file or directory"
              exit 1
            fi
            cp ${run-tests}/bin/run-tests $out/src/run-tests
          '' else
            installPhase;
        passthru = {
          python = python-env;
          bpython = run-bpython;
          jupyter = run-jupyter;
          test = run-tests;
          container = container-img;
          push-img = lib.campground.pushDockerImage {
            inherit pkgs;
            dockerImage = container-img;
          };
        };
        meta = meta;
      };
    in
    pyDerivation;

}
