{ lib
, writeText
, writeShellApplication
, substituteAll
, inputs
, pkgs
, hosts ? { }
, ...
}:
let
  inherit (lib) mapAttrsToList concatStringsSep;
  inherit (lib.campground) override-meta;

  new-meta = with lib; {
    description = "JupyterLab Docker Container";
    license = licenses.asl20;
    maintainers = with maintainers; [ mattcamp ];
  };

  image = pkgs.dockerTools.buildImage {
    name = "jupyterlab";
    config = {
      Cmd = [ "${pkgs.jupyterlab}/bin/jupyter-lab" ];
    };
  };
in

override-meta new-meta image
