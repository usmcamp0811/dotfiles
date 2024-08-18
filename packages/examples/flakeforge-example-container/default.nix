{
  lib,
  pkgs,
  ...
}:
let

  example = pkgs.streamLayeredImageConf {
    name = "flakeforge-example-container";
    tag = "latest";
    contents = [ pkgs.campground.blog ];
    config = {
      Entrypoint = [ "hugo-server" ];
    };
  };

in
example
