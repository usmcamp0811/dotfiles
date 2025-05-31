{ lib
, writeText
, writeShellApplication
, inputs
, pkgs
, hosts ? { }
, ...
}:
with lib;
with lib.campground; let
  inherit (lib) mapAttrsToList concatStringsSep;
  inherit (lib.campground) override-meta;

  campground.system.env = enabled;

  new-meta = with lib; {
    description = "nginx container";
    license = licenses.asl20;
    maintainers = with maintainers; [ bboterf ];
  };

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

  nginx-image = pkgs.dockerTools.buildImage {
    name = "layer-1";
    tag = "latest";
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
    config = {
      WorkingDir = "/www/data";
      Cmd = [ "${pkgs.nginx}/bin/nginx" ];
    };
  };
in
override-meta new-meta nginx-image
