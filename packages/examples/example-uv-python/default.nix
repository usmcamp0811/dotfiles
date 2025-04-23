{ pkgs
, lib
, ...
}:
let
  python-env = pkgs.ub-buildPythonPackage {
    src = ./.;
  };
in
python-env
