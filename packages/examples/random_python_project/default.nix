{ lib, pkgs, ... }:
with lib.initech;
let
  pypkgs-build-requirements = {
    snaptime = [ "setuptools" ];
  };

  name = "random-python";
  src = ./.;

  run-app = pkgs.writeShellScriptBin "run-app" ''
    ${random-python.python}/bin/python ${src}/random_python_project/random_python_project.py "$@"
  '';

  random-python = mkPythonDerivation {
    inherit
      pkgs
      name
      src
      pypkgs-build-requirements
      ;
    installPhase = ''
      cp ${run-app}/bin/run-app $out/bin/${name}
    '';
  };
in
random-python
