{ lib, inputs, pkgs, ... }:
let

  pluto =
    inputs.flakeforge.packages.x86_64-linux.flakeforgeTools.streamLayeredImageConf {
      name = "bash-stream-layered";
      contents = [ pkgs.campground.pluto ];
    };
in pluto
