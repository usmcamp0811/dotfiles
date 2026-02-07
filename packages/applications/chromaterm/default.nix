{ lib, inputs, pkgs, ... }:
with lib.fmf;
let
  chromaterm = mkPythonDerivation {
    inherit pkgs;
    name = "chromaterm";
    src = ./.;
    installPhase = ''
      mkdir -p $out/bin
      cp -r ${chromaterm.python}/bin/* $out/bin
    '';
    pypkgs-build-requirements = { chromaterm = [ "setuptools" ]; };

    meta = { mainProgram = "ct"; };
  };
in chromaterm
