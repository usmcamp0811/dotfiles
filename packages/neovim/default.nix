{
  inputs,
  system,
  lib,
  pkgs,
  ...
}: let
  config = import ./config;
in
  pkgs.nixvim.makeNixvimWithModule {
    inherit pkgs;
    module = config {inherit pkgs;};
  }
