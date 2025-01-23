{ config, pkgs, ... }: {
  config.data.http.public_ip = { url = "http://checkip.amazonaws.com/"; };
  config.provider.aws.region = "us-east-1";
  # Backend S3 configuration (requires a single bucket/key pair)
  config.backend.s3 = {
    bucket = "campground-state-bucket"; # Use a single bucket for state storage
    key = "state/terraform.tfstate";
    region = "us-east-1";
  };
  config.aws = {
    step_functions = {
      enable = true;
      workflows.pdf_ocr_workflow = {
        definition = {
          Comment = "A simple Step Function for PDF OCR";
          StartAt = "OCRProcessing";
          States = {
            OCRProcessing = {
              Type = "Task";
              Resource = config.resource.aws_lambda_function.pdf_ocr "arn";
              End = true;
            };
          };
        };
        lambda-functions.pdf_ocr = {
          lambda-image = pkgs.campground.aws-lambda-image;
          registry-name = "campground_ecr";
          environment = {
            INPUT_BUCKET = "initech-tps-reports-bucket";
            OUTPUT_BUCKET = "initech-output-bucket";
          };
          timeout = 120;
          memory_size = 512;
        };
      };
    };
    storage = {
      s3 = {
        enable = true;
        defaultIpWhiteList = [ ];
        buckets = { campground-input-bucket = { enable = true; }; };
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
          S3_BUCKET = "campground-output-bucket";
          S3_KEY = "forecasts/washington_dc_forecast.json";
        };
      };
      weather-job = {
        enable = true;
        variables = {
          LATITUDE = "40.4406"; # Latitude for Pittsburgh, PA
          LONGITUDE = "-79.9959"; # Longitude for Pittsburgh, PA
          S3_BUCKET = "campground-output-bucket";
          S3_KEY = "forecasts/pittsburgh_forecast.json";
        };
      };
    };
  };
}
