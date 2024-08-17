{
  lib,
  inputs,
  pkgs,
  ...
}:
let

  flask-app = pkgs.streamLayeredImageConf {
    name = "flakeforge-example-flask-app";
    tag = "latest";
    contents = [ pkgs.campground.example-flask-app ];
    config = {
      Entrypoint = [ "run-app" ];
    };
  };
in
flask-app
