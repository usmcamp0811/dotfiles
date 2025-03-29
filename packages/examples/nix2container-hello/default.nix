{ lib, pkgs, ... }:
with lib;
with lib.campground;
let

  nginxPort = "80";

  nginxWebRoot = pkgs.writeTextDir "index.html" ''
    <!doctype html>
    <html>
      <head><title>Hello nginx</title></head>
      <body><h1>Hello Nix2Container!</h1></body>
    </html>
  '';

  nginxConf = pkgs.writeText "nginx.conf" ''
    user nobody nobody;
    daemon off;
    error_log /dev/stdout info;
    pid /dev/null;

    events {}

    http {
      access_log /dev/stdout;
      server {
        listen ${nginxPort};
        index index.html;
        location / {
          root ${nginxWebRoot};
        }
      }
    }
  '';

  nginxVar = pkgs.runCommand "nginx-var" { } ''
    mkdir -p $out/var/log/nginx
    mkdir -p $out/var/cache/nginx
  '';
in
pkgs.nix2containerPkgs.nix2container.buildImage {
  name = "nix2container-hello";
  tag = "latest";
  copyToRoot = pkgs.buildEnv {
    name = "image-root";
    paths = [
      pkgs.dockerTools.fakeNss
      pkgs.nginx
      pkgs.coreutils
      pkgs.stdenv.cc.cc
      nginxVar
    ];
    pathsToLink = [ "/bin" "/lib64" "/etc" "/var" "/tmp" ];
  };
  config = {
    Cmd = [ "${pkgs.nginx}/bin/nginx" "-c" nginxConf ];
    ExposedPorts."${nginxPort}/tcp" = { };
  };
}
