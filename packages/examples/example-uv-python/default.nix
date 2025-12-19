{
  pkgs,
  lib,
  inputs,
  ...
}:
lib.fmf.mkUv2nixPythonEnv {
  inherit pkgs;
  workspaceRoot = ./.;
  python = pkgs.python312;
  # projectName will be auto-detected from pyproject.toml
  # envName will default to "example-python-env" or similar
}
# Usage:
# nix run .#your-package          # Runs the main program from pyproject.toml
# nix run .#your-package.python   # Runs the Python REPL
# result.passthru.python          # Access to Python interpreter

