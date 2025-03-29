{ lib
, writeText
, writeShellApplication
, substituteAll
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

  nginxConfContent = pkgs.writeText "nginx.conf" ''
    daemon off;

    events {
        worker_connections 1024;
    }

    http {

        server {
            listen 80;

            location / {
                root /www/data;
            }
        }
    }
  '';

  indexHTMLContent = pkgs.writeText "index.html" ''
    <!doctype html>
    <html>
      <head>
        <title>Hello nginx</title>
        <meta charset="utf-8" />
      </head>
      <body>
        <h1>
          Hello World!
        </h1>
      </body>
    </html>
  '';
  nginx-image = nix2container.buildImage {
    name = "layered";
    config = {
      WorkingDir = "/www/data";
      entrypoint = [ "${pkgs.nginx}/bin/nginx" ];
    };
    copyToRoot = pkgs.buildEnv {
      name = "image-root";
      pathsToLink = [ "/bin" ];
      paths = [ pkgs.coreutils pkgs.nginx ];
    };
    runAsRoot = ''
      mkdir -p www/data
      mkdir -p etc/nginx/
      mkdir -p var/log/nginx/
      cat ${indexHTMLContent} > www/data/index.html
      cat ${nginxConfContent} > etc/nginx/nginx.conf '';
    maxLayers = 3;
  };
in
nginx-image
