{ pkgs, lib, ... }:
with lib;
with lib.fmf;
let

  python-env =
    pkgs.python3.withPackages (ps: [ ps.pyyaml ps.deepdiff ps.configargparse ]);
  yaml-diff-analyzer-script = ./yaml-diff-analyzer.py;

in
pkgs.writeShellApplication {
  name = "yaml-diff-analyzer";
  text = ''
    ${python-env}/bin/python ${yaml-diff-analyzer-script} "$@"
  '';
}
