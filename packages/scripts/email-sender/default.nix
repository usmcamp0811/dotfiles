{ pkgs, lib, ... }:
with lib;
with lib.fmf;
let

  python-env = pkgs.python3.withPackages (ps: [ ps.configargparse ]);
  email-sender = ./email-sender.py;

in
pkgs.writeShellApplication {
  name = "email-sender";
  text = ''
    ${python-env}/bin/python ${email-sender} "$@"
  '';
}
