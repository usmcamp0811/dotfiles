{ lib, inputs, pkgs, ... }:
let

  my-bash-image =
    inputs.flakeforge.packages.x86_64-linux.flakeforgeTools.streamLayeredImageConf {
      name = "bash-stream-layered";
      contents = [ pkgs.campground.julia ];
    };
in my-bash-image
