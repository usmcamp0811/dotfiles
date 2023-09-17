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
    description = "Hello World Docker Image";
    license = licenses.asl20;
    maintainers = with maintainers; [ mattcamp ];
  };

  image = pkgs.dockerTools.buildImage {
    name = "hello-docker";
    config = {
      Cmd = [ "${pkgs.hello}/bin/hello" ];
    };
  };
in

override-meta new-meta image
