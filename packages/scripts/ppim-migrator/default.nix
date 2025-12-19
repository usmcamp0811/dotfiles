{ lib, inputs, pkgs, ... }:
with lib.fmf;
let

  ppim = pkgs.writeShellScriptBin "ppim-migrator" ''
    ${ppim-migrator.python}/bin/python -m ppim-migrator $@
  '';
  ppim-migrator = mkPythonDerivation {
    inherit pkgs;
    name = "ppim-migrator";
    src = ./.;
    installPhase = ''
      mkdir -p $out/bin
      cp -r ${ppim-migrator.python}/bin/* $out/bin
      cp ${ppim}/bin/ppim-migrator $out/bin
    '';
    # pypkgs-build-requirements = { chromaterm = [ "setuptools" ]; };

    meta = { mainProgram = "ppim-migrator"; };
  };
in ppim-migrator
