{ lib
, writeText
, writeShellApplication
, inputs
, pkgs
, hosts ? { }
, ...
}:
let
  inherit (lib) mapAttrsToList concatStringsSep;
  inherit (lib.campground) override-meta;

  new-meta = with lib; {
    description = "An Example Flink Job";
    license = licenses.asl20;
    maintainers = with maintainers; [ matt-camp ];
    mainProgram = "quix-job";
  };

  pypkgs-build-requirements = {
    avro = [ "setuptools" ];
    avro-python3 = [ "setuptools" "python-snappy" "zstandard" "isort" "pycodestyle" ];
    apache-quix = [ "setuptools" ];
    mocker = [ "setuptools" ];
    apache-quix-libraries = [ "setuptools" ];
  };

  p2n-overrides = pkgs.poetry2nix.defaultPoetryOverrides.extend (self: super:
    builtins.mapAttrs
      (package: build-requirements:
        super."${package}".overridePythonAttrs (oldAttrs: {
          buildInputs =
            (oldAttrs.buildInputs or [ ])
            ++ (builtins.map (req: super."${req}") build-requirements);

          # Additional override for apache-quix-libraries to avoid collision
          installPhase =
            if package == "apache-quix-libraries"
            then ''
              rm -rf $out/lib/python3.11/site-packages/pyquix/__pycache__/version.cpython-311.pyc
            ''
            else oldAttrs.postInstall or "";
        }))
      pypkgs-build-requirements);

  src = ./.;

  quix-job = pkgs.writeShellScriptBin "quix-job" ''
    ${pkgs.campground.example-quix-job.python}/bin/python ${src}/job/job.py
  '';

  run-tests = pkgs.writeShellScriptBin "run-tests" ''
    # Resolves the symlink to find the actual path of the script
    SCRIPT=$(readlink -f "$0" || realpath "$0")
    SCRIPT_DIR=$(dirname "$SCRIPT")

    # Adjusted to ensure it works regardless of where it's called from
    BASE_DIR=$(dirname "$SCRIPT_DIR")
    ${python-env}/bin/pytest $SCRIPT_DIR/tests/test_job.py "$@"
  '';

  python-env = pkgs.poetry2nix.mkPoetryEnv {
    projectDir = src;
    python = pkgs.python311;
    overrides = p2n-overrides;
    preferWheels = true; # Prefer wheels to speed up the build process
  };

  test-quix-job = pkgs.stdenv.mkDerivation {
    name = "test-quix-job";
    src = src;
    phases = [ "installPhase" ];
    propagatedBuildInputs = [ pkgs.openjdk8 python-env ];
    installPhase = ''
      mkdir -p $out/bin
      ln -s ${example-quix-job}/src/run-tests $out/bin/run-tests
    '';
    meta = {
      description = "Test for Example Flink Job";
      mainProgram = "run-tests";
    };
  };

  example-quix-job = pkgs.stdenv.mkDerivation {
    name = "example-quix-job";
    src = src;

    installPhase = ''
      mkdir -p $out/bin
      mkdir -p $out/src
      mkdir -p $out/opt/quix

      cp -r $src/* $out/src/
      cp -r ${python-env}/bin/* $out/bin/
      cp ${quix-job}/bin/quix-job $out/bin/
      cp ${run-tests}/bin/run-tests $out/src/run-tests
    '';

    passthru = {
      python = python-env;
      test = test-quix-job;
    };
  };
in
override-meta new-meta example-quix-job
