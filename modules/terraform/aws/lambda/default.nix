{ config, lib, pkgs, ... }:
with lib;
with lib.campground;
with types;

let
  cfg = config.aws.lambda;

  build-push-lambda-image = lambdaConfig:
    lib.campground.pushLambdaToAWS {
      inherit pkgs config;
      registryName = lambdaConfig.registry-name;
      lambdaImg = lambdaConfig.lambda-image;
    };

in {
  options.aws.lambda = {
    enable = mkBoolOpt false "Enable AWS Lambda Jobs";
    jobs = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          lambda-image = mkOpt package pkgs.campground.aws-lambda-image
            "The lambda image to use for the job";
          registry-name = mkOpt str "ata-ecr" "The name of the registry to use";
          environment.variables =
            mkOpt (types.attrsOf types.str) { foo = "bar"; }
            "Environment Variables for the Lambda Function";
        };
      });
      default = { };
      description = "Configuration for multiple AWS Lambda jobs";
    };
  };

  config = mkIf cfg.enable {
    aws.storage.ecr.enable = true;

    aws.storage.ecr.registeries = mapAttrsToList
      (name: lambdaConfig: { name = lambdaConfig.registry-name; }) cfg.jobs;

    resource.null_resource = mapAttrs (name: lambdaConfig: {
      provisioner = {
        local-exec = {
          command = "${build-push-lambda-image lambdaConfig}/bin/build-push ${
              config.resource.aws_ecr_repository."${lambdaConfig.registry-name}"
              "repository_url"
            }";
        };
      };
      depends_on = [ "aws_ecr_repository.${lambdaConfig.registry-name}" ];
      triggers = {
        always_run = true;
        registry_url =
          config.resource.aws_ecr_repository."${lambdaConfig.registry-name}"
          "repository_url";
        lambda_name = name;
      };
    }) cfg.jobs;

    data.aws_iam_policy_document.assume_role = {
      statement = {
        effect = "Allow";

        principals = {
          type = "Service";
          identifiers = [ "lambda.amazonaws.com" ];
        };

        actions = [ "sts:AssumeRole" ];
      };
    };

    resource.aws_iam_role.iam_for_lambda = {
      name = "iam_for_lambda";
      assume_role_policy =
        config.data.aws_iam_policy_document.assume_role "json";
    };

    resource.aws_lambda_function = mapAttrs (name: lambdaConfig: {
      package_type = "Image";
      image_uri = "${
          config.resource.aws_ecr_repository."${lambdaConfig.registry-name}"
          "repository_url"
        }:${lambdaConfig.lambda-image.imageName}";
      function_name = name;
      role = config.resource.aws_iam_role.iam_for_lambda "arn";
      environment = { variables = lambdaConfig.environment.variables; };
      depends_on = [
        "resource.null_resource.${name}"
        "resource.aws_iam_role.iam_for_lambda"
      ];
    }) cfg.jobs;
  };
}
