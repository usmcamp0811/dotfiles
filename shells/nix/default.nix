{ pkgs
, config
, lib
, self
, ...
}:
      
pkgs.devshell.mkShell {
  imports = [ (pkgs.devshell.importTOML ./devshell.toml) ];
}

