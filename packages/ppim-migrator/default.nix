{ lib, inputs, pkgs, ... }:
with lib.campground;
let
  ppim-migrator = mkPythonDerivation {
    inherit pkgs;
    name = "ppim-migrator";
    src = ./.;
    installPhase = ''
      mkdir -p $out/bin
      cp -r ${ppim-migrator.python}/bin/* $out/bin
    '';
    # pypkgs-build-requirements = { chromaterm = [ "setuptools" ]; };

    meta = { mainProgram = "ppim-migrator"; };
  };
in ppim-migrator
