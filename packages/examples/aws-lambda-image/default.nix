{ lib, pkgs, inputs, system, ... }:
with lib;
with lib.campground;
mkAWSLambdaPythonImage {
  inherit pkgs system;
  name = "github-api-lambda";
  handler = "handler";
  pythonSrc = ./simple_lambda_function.py;
  pythonEnv =
    pkgs.python3.withPackages (ps: [ ps.awslambdaric ps.requests ps.jsons ]);
}
