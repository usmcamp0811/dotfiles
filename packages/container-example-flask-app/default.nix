{ lib
, writeText
, writeShellApplication
, substituteAll
, gum
, inputs
, pkgs
, hosts ? { }
, ...
}:
with lib;
with lib.campground;
let
  inherit (lib) mapAttrsToList concatStringsSep;
  inherit (lib.campground) override-meta;
  pname = "simple-flask-app";

  description = "A Simple Flask App";

  version = "1.0.0";

  new-meta = with lib; {
    description = "A Simple Flask App Container Image";
    license = licenses.mit;
    maintainers = with maintainers; [ mattcamp ];
  };

  example-flask-image = pkgs.dockerTools.buildImage{
    name = "example-flask-app" ;
    tag = "latest";
    copyToRoot = pkgs.buildEnv{
      name = "image-root";
      pathsToLink = [ "/bin" ];
      paths = [ campground.example-flask-app ];
    };
    runAsRoot = ''
      # Create a new user for running uWSGI
      adduser -D uwsgi_user
    '';
    config = {
      WorkingDir = "/www/data";
      Cmd = [
        "/bin/su"
        "uwsgi_user"
        "-c"
        "${campground.example-flask-app}/bin/run-flask-app"
      ];
      ExposedPorts = {
        "8081/tcp" = {};
      };
    };
  };

in
override-meta new-meta example-flask-image
