{ pkgs
, config
, lib
, self
, ...
}:
with lib;
with lib.campground;
let
  inherit (lib.campground) override-meta;
in
pkgs.devshell.mkShell {
  imports = [ (pkgs.devshell.importTOML ./devshell.toml) ];
}

