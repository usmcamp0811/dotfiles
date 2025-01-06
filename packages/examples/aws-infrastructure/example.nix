{ config, pkgs, ... }: {
  # Backend S3 configuration (requires a single bucket/key pair)
  config.backend.s3 = {
    bucket = "state-bucket"; # Use a single bucket for state storage
    key = "state/example.terraform.tfstate";
    region = "us-east-1";
  };

  config.aws.storage.s3buckets = {
    enable = true;
    region = config.backend.s3.region;
    ip-white-list = [ "0.0.0.0/0" ];
    tags = {
      terranix = "true";
      project = "example-infrastructure";
    };
    buckets = [ "test-bucket" "another-bucket" ];
  };

  # Add the Lambda configuration
  config.aws.lambda = {
    enable = true;
    region = config.backend.s3.region;
    lambda = {
      myLambda = {
        functionName = "my-docker-lambda";
        handler = ""; # Not required for image-based Lambdas
        runtime = "provided.al2"; # AWS runtime for container-based Lambdas
        memorySize = 128; # Adjust based on your needs
        timeout = 30; # Adjust based on your needs

        # Role and policies
        role = {
          name = "lambda-exec-role";
          assumeRolePolicy = pkgs.lib.toJSON {
            Version = "2012-10-17";
            Statement = [{
              Effect = "Allow";
              Principal = { Service = "lambda.amazonaws.com"; };
              Action = "sts:AssumeRole";
            }];
          };
          policies = [{
            name = "lambda-logging-policy";
            policyDocument = pkgs.lib.toJSON {
              Version = "2012-10-17";
              Statement = [{
                Effect = "Allow";
                Action = [
                  "logs:CreateLogGroup"
                  "logs:CreateLogStream"
                  "logs:PutLogEvents"
                ];
                Resource = "arn:aws:logs:*:*:*";
              }];
            };
          }];
        };

        # Docker image configuration
        packageType = "Image";
        imageUri = "${config.aws.ecr.repositoryUrl}:latest";

        # ECR repository configuration
        ecrRepository = {
          name = "my-lambda-repo";
          tags = { project = "example-lambda"; };
        };

        # Null resource to push the Docker image
        pushImage = {
          provisioner = "local-exec";
          command = ''
            ${pkgs.awscli}/bin/aws ecr get-login-password --region ${config.backend.s3.region} \
              | ${pkgs.podman}/bin/podman login --username AWS --password-stdin ${config.aws.ecr.repositoryUrl}
            ${pkgs.podman}/bin/podman tag ./result:latest ${config.aws.ecr.repositoryUrl}:latest
            ${pkgs.podman}/bin/podman push ${config.aws.ecr.repositoryUrl}:latest
          '';
          triggers = {
            imageDigest =
              pkgs.lib.fileHash ./result; # Ensure it's rebuilt on changes
          };
        };
      };
    };
  };
}
