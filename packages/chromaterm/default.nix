{ lib, writeText, writeShellApplication, substituteAll, inputs, pkgs
, hosts ? { }, ... }:
let
  inherit (lib) mapAttrsToList concatStringsSep;
  inherit (lib.campground) override-meta;

  new-meta = with lib; {
    description = "A Nix packaging of a Python package using Poetry2Nix";
    license = licenses.asl20;
    maintainers = with maintainers; [ matt-camp ];
    mainProgram = "ct";
  };

  pypkgs-build-requirements = { chromaterm = [ "setuptools" ]; };

  p2n-overrides = pkgs.poetry2nix.defaultPoetryOverrides.extend (self: super:
    builtins.mapAttrs (package: build-requirements:
      (builtins.getAttr package super).overridePythonAttrs (old: {
        buildInputs = (old.buildInputs or [ ]) ++ (builtins.map (pkg:
          if builtins.isString pkg then builtins.getAttr pkg super else pkg)
          build-requirements);

      })) pypkgs-build-requirements);

  chromaterm-env = pkgs.poetry2nix.mkPoetryEnv {
    projectDir = ./.;
    overrides = p2n-overrides;
    python = pkgs.python311;
  };

  chromaterm = pkgs.stdenv.mkDerivation {
    name = "chromaterm";
    src = ./.;
    phases = [ "installPhase" ];
    # buildInputs = [ chromaterm-env ];
    installPhase = ''
      mkdir -p $out/bin
      cp -r ${chromaterm-env}/bin/* $out/bin
    '';
  };
in override-meta new-meta chromaterm
