{ pkgs, lib, ... }:
with lib;
let

  python-env = pkgs.python3.withPackages (ps: [
    ps.pypdf2
    ps.configargparse
    ps.pdf2image
    ps.pillow
    ps.tkinter
    ps.simplejson
  ]);
  pdf-draw = ./pdf_draw.py;

in pkgs.writeShellApplication {
  name = "pdf_draw";
  text = ''
    ${python-env}/bin/python ${pdf-draw} "$@"
  '';
}
