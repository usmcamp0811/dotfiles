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
    contents = [
      pkgs.campground.example-flask-app
      pkgs.bashInteractive
    ];
    config = {
      Entrypoint = [ "example-flask-app" ];
    };
  };
in
flask-app
