{ lib
, writeText
, writeShellApplication
, substituteAll
, inputs
, pkgs
, hosts ? { }
, ...
}:
with lib;
with lib.campground;
let
  conf = ./tmux.conf;
  tmux = pkgs.writeShellApplication {
    name = "campground-tmux";
    runtimeInputs = [ pkgs.tmux ];
    text = ''
      ${pkgs.tmux}/bin/tmux -f ${conf} "$@"
    '';
  };

in
tmux
