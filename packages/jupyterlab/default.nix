{ pkgs ? import <nixpkgs> {} }:

let
  jupyenv = import (pkgs.fetchFromGitHub {
    owner = "tweag";
    repo = "jupyenv";
    rev = "master";  # Replace with a specific commit or tag if needed
    sha256 = "...";  # Replace with the correct SHA-256 hash
  });

  mkJupyterlabNew = jupyenv.lib.mkJupyterlabNew;

  jupyterlabEnv = mkJupyterlabNew {
    nixpkgs = pkgs;
  };
  
in
pkgs.stdenv.mkDerivation {
  name = "jupyterlab-with-jupyenv";

  buildInputs = [ jupyterlabEnv ];

  shellHook = ''
    echo "To run Jupyter Lab, execute: jupyter-lab"
  '';
}
