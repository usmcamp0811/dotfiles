{ pkgs, ... }:

pkgs.runCommand "example-flask-app" { src = ./.; } ''

  mkdir -p $out
  ${pkgs.fmf.example-flask-app.python}/bin/python -c "import flask; print(flask.__version__)" > $out/results.txt
''
