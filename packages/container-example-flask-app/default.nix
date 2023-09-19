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
  # allows us to just use the app/package
  inherit (pkgs.campground) example-flask-app;
  pname = "simple-flask-app";

  description = "A Simple Flask App";

  version = "1.0.0";

  new-meta = with lib; {
    description = "A Simple Flask App Container Image";
    license = licenses.mit;
    maintainers = with maintainers; [ mattcamp ];
  };

  example-flask-image = let
    nonRootShadowSetup = { user, uid, gid ? uid }: with pkgs; [
      (
      writeTextDir "etc/shadow" ''
        root:!x:::::::
        ${user}:!:::::::
      ''
      )
      (
      writeTextDir "etc/passwd" ''
        root:x:0:0::/root:${runtimeShell}
        ${user}:x:${toString uid}:${toString gid}::/home/${user}:
      ''
      )
      (
      writeTextDir "etc/group" ''
        root:x:0:
        ${user}:x:${toString gid}:
      ''
      )
      (
      writeTextDir "etc/gshadow" ''
        root:x::
        ${user}:x::
      ''
      )
    ];
  in
  pkgs.dockerTools.buildLayeredImage{
    name = "example-flask-app" ;
    tag = "latest";
    contents = [ example-flask-app pkgs.bash pkgs.coreutils ] ++ nonRootShadowSetup { uid = 999; user = "uwsgi_user"; };
    extraCommands = ''
      mkdir -p usr/bin
      cat ${example-flask-app}/bin/run-flask-app > /usr/bin/run-flask-app
      chmod +x /usr/bin/run-flask-app
    '';
    config = {
      WorkingDir = "/www/data";
      Cmd = [
        "/bin/sh ${example-flask-app}/bin/run-flask-app"
      ];
      ExposedPorts = {
        "8081/tcp" = {};
      };
    };
  };

in
override-meta new-meta example-flask-image
