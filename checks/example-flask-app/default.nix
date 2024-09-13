{ pkgs, ... }:

pkgs.runCommand "example-flask-app" { src = ./.; } ''
  mkdir -p $out
  ${pkgs.campground.example-flask-app}/bin/example-flask-app > $out/results.txt
''
