{
  pkgs,
  lib,
  ...
}:
lib.fmf.mkUv2nixPythonEnv {
  inherit pkgs;
  workspaceRoot = ./.;
  python = pkgs.python312;
}
