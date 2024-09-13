{ lib, writeText, writeShellApplication, substituteAll, inputs, pkgs
, hosts ? { }, ... }:
let
  inherit (lib) mapAttrsToList concatStringsSep;
  inherit (lib.campground) override-meta;

  new-meta = with lib; {
    description = "My goto Python";
    license = licenses.asl20;
    maintainers = with maintainers; [ matt-camp ];
    mainProgram = "python";
  };

  pypkgs-build-requirements = {
    avro = [ "setuptools" ];
    avro-python3 =
      [ "setuptools" "python-snappy" "zstandard" "isort" "pycodestyle" ];
    apache-flink = [ "setuptools" ];
    mocker = [ "setuptools" ];
    apache-flink-libraries = [ "setuptools" ];
  };

  p2n-overrides = pkgs.poetry2nix.defaultPoetryOverrides.extend (self: super:
    builtins.mapAttrs (package: build-requirements:
      super."${package}".overridePythonAttrs (oldAttrs: {
        buildInputs = (oldAttrs.buildInputs or [ ])
          ++ (builtins.map (req: super."${req}") build-requirements);

        # Additional override for apache-flink-libraries to avoid collision
        installPhase = if package == "apache-flink-libraries" then ''
          rm -rf $out/lib/python3.11/site-packages/pyflink/__pycache__/version.cpython-311.pyc
        '' else
          oldAttrs.postInstall or "";
      })) pypkgs-build-requirements);

  pythonInFHS = (pkgs.scientific-fhs.override (oldAttrs: {
    commandScript = "python";
    juliaEnv = pkgs.campground.julia;
    poetryEnv = python-env;
  }));

  bashInFHS = (pkgs.scientific-fhs.override (oldAttrs: {
    commandScript = "bash";
    juliaEnv = pkgs.campground.julia;
    poetryEnv = python-env;
  }));

  python-env = pkgs.poetry2nix.mkPoetryEnv {
    projectDir = src;
    python = pkgs.python312;
    overrides = p2n-overrides;
    preferWheels = true; # Prefer wheels to speed up the build process
  };

  src = ./.;

in python-env // {
  FHS = {
    python = pythonInFHS;
    bash = bashInFHS;
  };
}
