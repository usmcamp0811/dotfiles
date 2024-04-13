{pkgs}: let
  pypkgs-build-requirements = {pandas = ["versioneer"];};
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
in
  pkgs.poetry2nix.mkPoetryEnv {
    projectDir = ./.;
    python = pkgs.python3;
    overrides = p2n-overrides;
    preferWheels = true;
  }
