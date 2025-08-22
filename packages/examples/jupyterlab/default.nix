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
      env = pkgs.campground.example-uv-python;
      # python = pkgs.python313;
    };
  };
in
  jupyterlab
