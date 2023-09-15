{ mkShell
, pkgs
, ...
}:
let
  # Import the devshell TOML configuration
  devshellConfig = pkgs.devshell.importTOML ./devshell.toml;
in
  pkgs.devshell.mkShell {
    imports = [ devshellConfig ];
  }
}

