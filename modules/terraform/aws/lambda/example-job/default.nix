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
        environment.variables = {
          LATITUDE = "40.4406"; # Latitude for Pittsburgh, PA
          LONGITUDE = "-79.9959"; # Longitude for Pittsburgh, PA
          S3_BUCKET = "my-weather-data"; # Replace with your S3 bucket name
          S3_KEY =
            "forecasts/pittsburgh_forecast.json"; # Replace with your desired S3 key
        };
      };
    };
  };
}
