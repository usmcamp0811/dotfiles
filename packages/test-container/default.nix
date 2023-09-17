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
  image = pkgs.dockerTools.buildImage {
    name = "hello-docker";
    config = {
      Cmd = [ "${pkgs.hello}/bin/hello" ];
    };
  };
in

override-meta new-meta image
