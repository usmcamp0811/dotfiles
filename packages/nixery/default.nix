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
let
  inherit (lib) mapAttrsToList concatStringsSep;
  inherit (lib.campground) override-meta;

  pname = "nixery";
  version = "0.44.4";
  # storagePath = "/var/lib/nixery";

  # nixery = specialArgs.nixery-pkgs.nixery.overrideAttrs(old: {
  #   # Drop the nix-1p documentation page as it doesn't build in pure evaluation.
  #   postInstall = ''
  #     wrapProgram $out/bin/server \
  #       --prefix PATH : ${specialArgs.nixery-pkgs.nixery-prepare-image}/bin \
  #       --prefix PATH : ${nix}/bin
  #   '';
  # });

  new-meta = with lib; {
    description = "Nixery";
    license = licenses.asl20;
    maintainers = with maintainers; [ mattcamp ];
  };

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

  uwsgiWithPython3 = pkgs.uwsgi.override {
    plugins = [ "python3" ];
  };

  pythonWithFlask = pkgs.python3.withPackages (ps: [ ps.flask ]);

  example-flask-app = pkgs.stdenv.mkDerivation {
    name = "${pname}-${version}";
    src = flaskApp;
    phases = [ "installPhase" ];
    buildInputs = [ pythonWithFlask uwsgiWithPython3 ];

  # Build a derivation for the Flask app
    installPhase = ''
      install -Dm644 $src $out/bin/app.py
      mkdir -p $out/etc
      cat <<EOL > $out/etc/uwsgi.ini
      [uwsgi]
      wsgi-file = $out/bin/app.py
      callable = app
      socket = :8081
      http = :8080
      processes = 4
      threads = 2
      master = true
      chmod-socket = 660
      vacuum = true
      plugins = python3
      die-on-term = true
      EOL
      echo "#!/bin/sh" > $out/bin/run-flask-app
      echo "export PYTHONPATH=${pythonWithFlask}/lib/python3.10/site-packages" >> $out/bin/run-flask-app
      echo "${uwsgiWithPython3}/bin/uwsgi --ini $out/etc/uwsgi.ini" >> $out/bin/run-flask-app
      chmod +x $out/bin/run-flask-app
      echo "#!/usr/bin/env sh" > $out/bin/dev-flask-app
      echo "${pythonWithFlask.interpreter} $out/bin/app.py" >> $out/bin/dev-flask-app
      chmod +x $out/bin/dev-flask-app
    '';
  };
in
# {
#   # If k0s should be in the PATH:
#   # environment.systemPackages = [ k0s ];
#
# }

override-meta new-meta example-flask-app
