{ lib, pkgs, ... }:
with lib.fmf;
let
  pypkgs-build-requirements = { snaptime = [ "setuptools" ]; };

  name = "random-python";
  src = ./.;

  run-app = pkgs.writeShellScriptBin name ''
    ${random-python.python}/bin/python ${src}/random_python_project/random_python_project.py "$@"
  '';

  random-python = mkPythonDerivation {
    inherit pkgs name src pypkgs-build-requirements;
    installPhase = ''
      mkdir -p $out/bin
      cp ${run-app}/bin/${name} $out/bin/${name}
    '';
  };
in
random-python
