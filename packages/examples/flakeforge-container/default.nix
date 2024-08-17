{ lib, inputs, pkgs, ... }:
let

  my-bash-image =
    inputs.flakeforge.packages.x86_64-linux.flakeforgeTools.streamLayeredImageConf {
      name = "bash-stream-layered";
      contents = [ nixpkgs.legacyPackages.x86_64-linux.bashInteractive ];
    };
in my-bash-image
