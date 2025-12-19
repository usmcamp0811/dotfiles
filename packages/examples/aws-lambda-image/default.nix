{ lib, pkgs, inputs, system, ... }:
with lib;
with lib.fmf;
mkAWSLambdaPythonImage {
  inherit pkgs system;
  name = "weather-example";
  handler = "simple_lambda_function.handler";
  src = ./.;
  pythonEnv = pkgs.python3.withPackages
    (ps: [ ps.awslambdaric ps.requests ps.jsons ps.boto3 ps.tenacity ]);
}
