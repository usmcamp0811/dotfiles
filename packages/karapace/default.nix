{
  lib,
  writeText,
  writeShellApplication,
  substituteAll,
  inputs,
  pkgs,
  hosts ? {},
  ...
}: let
  inherit (lib) mapAttrsToList concatStringsSep;
  inherit (lib.campground) override-meta;

  new-meta = with lib; {
    description = "Karapace - a Kafka Schema Registry and REST Proxy";
    homepage = "https://github.com/Aiven-Open/karapace";
    license = licenses.mit;  # Update the license if necessary
    maintainers = with maintainers; [matt-camp];
  };

  pname = "karapace";
  version = "3.12.0"; 

  pypkgs-build-requirements = {
    accept-types = ["setuptools"];
  };

# accept-types = "^0.4.1"
# aiohttp = "^3.9.5"
# aiokafka = "^0.10.0"
# avro = "^1.11.3"
# jsonschema = "^4.21.1"
# kafka-python = "^2.0.2"
# networkx = "^3.3"
# protobuf = "^5.26.1"
# pyjwt = "^2.8.0"
# python-dateutil = "^2.9.0.post0"
# lz4 = "^4.3.3"
# python-snappy = "^0.7.1"
# zstandard = "^0.22.0"
# sentry-sdk = "^1.45.0"
# ujson = "^5.9.0"

  p2n-overrides = pkgs.poetry2nix.defaultPoetryOverrides.extend (self: super:
    builtins.mapAttrs (package: build-requirements:
      (builtins.getAttr package super).overridePythonAttrs (old: {
        buildInputs =
          (old.buildInputs or [])
          ++ (builtins.map (pkg:
            if builtins.isString pkg
            then builtins.getAttr pkg super
            else pkg)
          build-requirements);
      }))
    pypkgs-build-requirements);


  python-env = pkgs.poetry2nix.mkPoetryEnv {
    projectDir = ./.;
    overrides = p2n-overrides;
    python = pkgs.python311;
  };


  karapace = pkgs.python3Packages.buildPythonApplication {
    inherit pname;
    inherit version;

    src = pkgs.fetchFromGitHub {
      owner = "Aiven-Open";
      repo = "karapace";
      rev = version;
      sha256 = "sha256-Gw4R8QZOfP0cqxMPaes0MGOt0Qd4wJn9SWlcGq+D9b8=";  # Placeholder hash
    };

    preBuild = ''
      export KARAPACE_VERSION="${version}"
    '';

    propagatedBuildInputs = [
      python-env
      pkgs.python311Packages.zstandard
      pkgs.python311Packages.python-snappy
      pkgs.python311Packages.typing-extensions
      pkgs.python311Packages.cachetools
      pkgs.python311Packages.confluent-kafka
      pkgs.python311Packages.aiohttp
      pkgs.python311Packages.aiokafka
      pkgs.python311Packages.avro
      pkgs.python311Packages.aiohttp
      pkgs.python311Packages.jsonschema
      pkgs.python311Packages.networkx
      pkgs.python311Packages.protobuf
      pkgs.python311Packages.pyjwt
      pkgs.python311Packages.ujson
      pkgs.python311Packages.sentry-sdk
      pkgs.python311Packages.python-dateutil
      pkgs.python311Packages.kafka-python
    ];
    doCheck = false;

    meta = with lib; {
      description = "Karapace - a Kafka Schema Registry and REST Proxy";
      homepage = "https://github.com/Aiven-Open/karapace";
      license = licenses.mit;  # Update the license if necessary
      maintainers = with maintainers; [ ];  # Add maintainers here
    };
  };

in
# python-env
  override-meta new-meta karapace
