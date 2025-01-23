{ config, lib, pkgs, ... }:
with lib;
with lib.campground;
with types;

let cfg = config.aws.step_function;

in {
  options.aws.step_function = {
    enable = mkBoolOpt false "Enable AWS Step Functions";

    workflows = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          definition = mkOption {
            type = types.attrs;
            description = "The JSON definition of the Step Function workflow";
          };

          lambda-functions = mkOption {
            type = types.attrsOf (types.submodule {
              options = {
                lambda-image = mkOption {
                  type = package;
                  description = "The Lambda image to use";
                };
                registry-name = mkOption {
                  type = str;
                  default = "campground_ecr";
                  description =
                    "The name of the registry to use for the Lambda function";
                };
                environment = mkOption {
                  type = types.attrsOf types.str;
                  default = { };
                  description = "Environment variables for the Lambda function";
                };
                timeout = mkOption {
                  type = int;
                  default = 60;
                  description = "Timeout for the Lambda function in seconds";
                };
                memory_size = mkOption {
                  type = int;
                  default = 256;
                  description = "Memory size for the Lambda function in MB";
                };
              };
            });
            description =
              "Lambda functions required by the Step Function workflow";
          };
        };
      });
      description = "Configuration for AWS Step Function workflows";
    };
  };

  config = mkIf cfg.enable {
    # Enable Lambda module since Step Functions depend on Lambda
    aws.lambda.enable = true;

    aws.lambda.jobs = mapAttrs
      (name: lambdaConfig: {
        lambda-image = lambdaConfig.lambda-image;
        registry-name = lambdaConfig.registry-name;
        environment.variables = lambdaConfig.environment;
        timeout = lambdaConfig.timeout;
        memory_size = lambdaConfig.memory_size;
      })
      (concatMapAttrs (_: wf: wf.lambda-functions) cfg.workflows);

    resource.aws_sfn_state_machine = mapAttrs
      (name: wf: {
        name = name;
        role_arn = config.resource.aws_iam_role.iam_for_step_function "arn";
        definition = builtins.toJSON wf.definition;
        depends_on =
          map (lambdaName: "resource.aws_lambda_function.${lambdaName}")
            (builtins.attrNames wf.lambda-functions)
          ++ [ "resource.aws_iam_role.iam_for_step_function" ];
      })
      cfg.workflows;

    data.aws_iam_policy_document.step_function_execution = {
      statement = [{
        effect = "Allow";
        actions = [ "lambda:InvokeFunction" ];
        resources =
          map (name: config.resource.aws_lambda_function.${name} "arn")
            (builtins.attrNames
              (concatMapAttrs (_: wf: wf.lambda-functions) cfg.workflows));
      }];
    };

    resource.aws_iam_role.iam_for_step_function = {
      name = "iam_for_step_function";
      assume_role_policy =
        config.data.aws_iam_policy_document.assume_role "json";
    };

    resource.aws_iam_role_policy.step_function_execution_policy = {
      name = "step_function_execution_policy";
      role = config.resource.aws_iam_role.iam_for_step_function "id";
      policy =
        config.data.aws_iam_policy_document.step_function_execution "json";
    };
  };
}
