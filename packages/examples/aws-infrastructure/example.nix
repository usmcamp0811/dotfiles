{ config, pkgs, ... }: {

  config.provider.aws.region = "us-east-1";
  # Backend S3 configuration (requires a single bucket/key pair)
  config.backend.s3 = {
    bucket = "campground-state-bucket"; # Use a single bucket for state storage
    key = "state/terraform.tfstate";
    region = "us-east-1";
  };
  config.aws = {
    storage = {
      s3 = {
        enable = true;
        defaultIpWhiteList = [ "0.0.0.0/0" ];
        buckets = { another-bucket = { enable = true; }; };
      };
      ecr = {
        enable = true;
        registeries = [{ name = "my-main-ecr"; }];
      };
    };

    lambda = {
      jobs.another-example-job = {
        lambda-image = pkgs.campground.aws-lambda-image;
        environment.variables = {
          LATITUDE = "38.9072";
          LONGITUDE = "-77.0369";
          S3_BUCKET = "weather-data";
          S3_KEY = "forecasts/washington_dc_forecast.json";
        };
      };
      weather-job = {
        enable = true;
        variables = {
          LATITUDE = "40.4406"; # Latitude for Pittsburgh, PA
          LONGITUDE = "-79.9959"; # Longitude for Pittsburgh, PA
          S3_BUCKET = "weather-data";
          S3_KEY = "forecasts/pittsburgh_forecast.json";
        };
      };
    };
  };
}
