{ config, ... }: {
  # Backend S3 configuration (requires a single bucket/key pair)
  config.backend.s3 = {
    bucket = "state-bucket"; # Use a single bucket for state storage
    key = "state/terraform.tfstate";
    region = "us-east-1";
  };
  config.aws = {
    storage = {
      s3buckets = {
        enable = true;
        region = config.backend.s3.region;
        ip-white-list = [ "0.0.0.0/0" ];
        tags = {
          terranix = "true";
          project = "example-infrastructure";
        };
        buckets = [ "my-test-bucket" "another-bucket" ];
      };
      ecr = {
        enable = true;
        registeries = [{ name = "my-main-ecr"; }];
      };
    };
    lambda = {
      enable = true;
      registry-name = "lambda-ecr";
    };
  };
}
