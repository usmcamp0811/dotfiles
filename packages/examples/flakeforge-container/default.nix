{ lib, inputs, pkgs, ... }:
let

  my-bash-image = pkgs.flakeforgeTools.streamLayeredImageConf {
    name = "bash-stream-layered";
    contents = [ pkgs.campground.julia ];
  };
in my-bash-image
