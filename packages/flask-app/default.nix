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
  pname = "simple-flask-app";

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

  pythonWithFlask = pkgs.python3.withPackages (ps: [ ps.flask ]);

  # Build a derivation for the Flask app
  example-flask-app = pkgs.stdenv.mkDerivation {
    name = "${pname}-${version}";
    src = flaskApp;
    phases = [ "installPhase" ];
    buildInputs = [ pythonWithFlask ];

    installPhase = ''
      install -Dm644 $src $out/bin/app.py
      echo "#!/usr/bin/env sh" > $out/bin/run-flask-app
      echo "${pythonWithFlask.interpreter} $out/bin/app.py" >> $out/bin/run-flask-app
      chmod +x $out/bin/run-flask-app
    '';
  };

  new-meta = with lib; {
    description = "A Simple Flask App";
    license = licenses.mit;
    maintainers = with maintainers; [ mattcamp ];
  };
in
override-meta new-meta example-flask-app
