{ pkgs, lib, ... }:
with lib;
with lib.fmf;
let

  python-env = pkgs.python3.withPackages (ps: [ ps.pypdf2 ps.configargparse ]);
  pdf-to-json = ./pdf-to-json.py;

in
pkgs.writeShellApplication {
  name = "pdf-to-json";
  text = ''
    ${python-env}/bin/python ${pdf-to-json} "$@"
  '';
}
