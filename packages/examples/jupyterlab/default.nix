{pkgs, ...}: let
  jupyterlab = pkgs.mkJupyterlabNew ({...}: {
    nixpkgs = pkgs;
    imports = [minimal-kernel];
  });

  minimal-kernel = {
    kernel.python.minimal = {
      enable = true;
    };
    kernel.python.example-env = {
      enable = true;
      displayName = "Python Environment (uv2nix)";
      env = pkgs.fmf.example-uv-python;
      python = pkgs.python312;
    };
  };
in
  jupyterlab
