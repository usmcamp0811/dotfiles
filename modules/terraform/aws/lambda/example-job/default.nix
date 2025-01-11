{ config, lib, pkgs, ... }:
with lib;
with lib.campground;
with types;

let cfg = config.aws.lambda.example-job;

in {
  options.aws.lambda.example-job = {
    enable = mkBoolOpt false "Enable the Example Lambda Job";
    registry-name = mkOpt str config.aws.lambda.default-registry
      "The name of the registry to use";
    variables = mkOpt (types.attrsOf types.str) { foo = "bar"; }
      "Environment Variables for the Lambda Function";
  };

  config = mkIf cfg.enable {
    aws.lambda.enable = true;
    aws.lambda.jobs = {
      example-job = {
        lambda-image = pkgs.campground.aws-lambda-image;
        registry-name = cfg.registry-name;
        environment.variables = cfg.variables;
      };
    };
  };
}
