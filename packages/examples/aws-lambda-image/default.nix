{ lib, pkgs, inputs, system, ... }:
with lib;
with lib.campground;
mkAWSLambdaPythonImage {
  inherit pkgs system;
  name = "github-api-lambda";
  pythonSrc = ./simple-lambda-function.py;
  pythonEnv = pkgs.python3.withPackages (ps: [ ps.requests ps.json ]);
}
