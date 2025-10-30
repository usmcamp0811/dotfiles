{ lib, pkgs, ... }:
let
  inherit (lib) mapAttrsToList concatStringsSep;
  inherit (lib.namespace-change-me) override-meta;
  pname = "example-flask-app";

  description = "A Simple Flask App";

  version = "1.0.0";

  # Create a simple Flask app
  flaskApp = pkgs.writeText "app.py" ''
    from flask import Flask

    app = Flask(__name__)
    app.debug = True

    @app.route('/')
    def hello():
        return "Hello World!"

    @app.route('/<name>')
    def hello_name(name):
        return "Hello {}!".format(name)

    if __name__ == '__main__':
        app.run()
  '';

  python-env = pkgs.python3.withPackages (ps: [ ps.flask ]);

  container = pkgs.dockerTools.buildLayeredImage {
    name = "example-flask-app";
    tag = "latest";
    contents = [ run-with-wsgi ];
    config = { Entrypoint = [ "run-app" ]; };
  };

  example-flask-app = pkgs.stdenv.mkDerivation {
    name = "${pname}-${version}";
    src = flaskApp;
    phases = [ "installPhase" ];
    buildInputs = [ run-with-wsgi ];

    # Build a derivation for the Flask app
    installPhase = ''
      mkdir -p $out/src
      mkdir -p $out/bin
      cp -r ${flaskApp} $out/src/app.py
      cp ${run-with-wsgi}/bin/run-app $out/bin/example-flask-app
    '';
    passthru = { container = container; };
  };
  uwsgi = pkgs.uwsgi.override {
    python3 = python-env;
    plugins = [ "python3" ];
  };

  run-with-wsgi = pkgs.writeShellApplication {
    name = "run-app";
    text = ''
      export PYTHONPATH="${python-env}/lib/python${
        builtins.substring 0 4 python-env.python.version
      }/site-packages"
      ${uwsgi}/bin/uwsgi --ini ${app_ini}
    '';
  };

  app_ini = pkgs.writeText "api.ini" ''
    [uwsgi]
    wsgi-file = ${flaskApp}
    callable = app
    http = :8080
    processes = 4
    threads = 2
    master = true
    chmod-socket = 660
    vacuum = true
    plugins = python3
    die-on-term = true
  '';
in example-flask-app
