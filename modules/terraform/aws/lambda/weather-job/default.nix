{ config, lib, pkgs, ... }:
with lib;
with lib.campground;
with types;

let cfg = config.aws.lambda.weather-job;

in {
  options.aws.lambda.weather-job = {
    enable = mkBoolOpt false "Enable the Example Lambda Job";
    registry-name =
      mkOpt str "campground_ecr" "The name of the registry to use";
    variables = mkOpt (types.attrsOf types.str)
      {
        LATITUDE = "40.4406"; # Latitude for Pittsburgh, PA
        LONGITUDE = "-79.9959"; # Longitude for Pittsburgh, PA
        S3_BUCKET = "my-weather-data"; # Replace with your S3 bucket name
        S3_KEY =
          "forecasts/pittsburgh_forecast.json"; # Replace with your desired S3 key
      } "Environment Variables for the Lambda Function";
  };

  config = mkIf cfg.enable {
    aws = {
      storage.s3 = {
        enable = true;
        buckets."${cfg.variables.S3_BUCKET}" = { enable = true; };
      };
      lambda = {
        enable = true;
        jobs = {
          weather-job = {
            lambda-image = pkgs.campground.aws-lambda-image;
            registry-name = cfg.registry-name;
            environment.variables = cfg.variables;
            depends_on =
              [ "resource.aws_s3_bucket.${cfg.variables.S3_BUCKET}" ];
          };
        };
      };
    };
    # IAM Policy for Lambda Role
    data.aws_iam_policy_document.s3_policy = {
      statement = [{
        effect = "Allow";
        actions = [ "s3:PutObject" ];
        resources = [ "arn:aws:s3:::${cfg.variables.S3_BUCKET}/*" ];
      }];
    };
    # IAM Role for Lambda
    resource = {
      aws_iam_role.iam_for_lambda = {
        name = "iam_for_lambda";
        assume_role_policy =
          config.data.aws_iam_policy_document.assume_role "json";
      };
      aws_iam_role_policy.s3_access_policy = {
        name = "s3_access_policy";
        role = config.resource.aws_iam_role.iam_for_lambda.name;
        policy = config.data.aws_iam_policy_document.s3_policy "json";
        depends_on = [ "resource.aws_iam_role.iam_for_lambda" ];
      };
    };
  };
}
