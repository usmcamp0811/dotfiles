{ config, lib, pkgs, ... }:
with lib;
with lib.campground;
with types;

let
  cfg = config.aws.lambda;
  build-push-lambda-image = lib.campground.pushLambdaToAWS {
    inherit pkgs config;
    registryName = cfg.registry-name;
    lambdaImg = pkgs.campground.aws-lambda-image;
  };

  repoUrl =
    config.resource.aws_ecr_repository."${cfg.registry-name}" "repository_url";
in {
  options.aws.lambda = {
    enable = mkBoolOpt false "Enable AWS Lambda Jobs";
    lambda-name = mkOpt str "${cfg.lambda-image.imageName}" "Lambda Job Name";
    lambda-image = mkOpt package pkgs.campground.aws-lambda-image
      "The lambda image to use for the job";
    registry-name = mkOpt str "ata-ecr" "The name of the registry to use";
    environment.variables = mkOpt (types.attrsOf types.str) { foo = "bar"; }
      "Environment Variables for the Lambda Function";
  };

  config = mkIf cfg.enable {
    aws.storage.ecr.enable = true;
    aws.storage.ecr.registeries = [{ name = cfg.registry-name; }];

    resource.null_resource.docker_build_and_push = {
      provisioner = {
        local-exec = {
          command = "${build-push-lambda-image}/bin/build-push ${repoUrl}";
        };
      };
      depends_on = [ "resource.aws_ecr_repository.${cfg.registry-name}" ];
      triggers = {
        # Force rerun by adding a timestamp or hash of related inputs
        # TODO: Only triger if the image changes
        always_run = true;
        registry_url = repoUrl;
        lambda_name = cfg.lambda-name;
      };
    };

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

    resource.aws_lambda_function."${cfg.lambda-name}" = {
      package_type = "Image";
      image_uri = "${repoUrl}:${cfg.lambda-image.imageName}";
      function_name = "lambda_function_name";
      role = config.resource.aws_iam_role.iam_for_lambda "arn";
      environment = { variables = cfg.environment.variables; };
      depends_on = [
        "resource.null_resource.docker_build_and_push"
        "resource.aws_iam_role.iam_for_lambda"
      ];
    };
  };
}
