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

    @app.route('/')
    def hello_world():
        return 'Hello, World!'
  '';

  # Build a derivation for the Flask app
  simpleFlaskApp = pkgs.stdenv.mkDerivation {
    name = "${pname}-${version}";
    src = flaskApp;
    buildInputs = [ pkgs.python3Packages.flask ];
    phases = [ "installPhase" ];
    installPhase = ''
      install -Dm644 $src $out/bin/app.py
    '';
  };

  new-meta = with lib; {
    description = "A Simple Flask App";
    license = licenses.mit;
    maintainers = with maintainers; [ mattcamp ];
  };
in
override-meta new-meta simpleFlaskApp
