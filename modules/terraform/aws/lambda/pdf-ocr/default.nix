{ config, lib, pkgs, ... }:
with lib;
with lib.campground;
with types;

let cfg = config.aws.lambda.pdf-ocr;

in {
  options.aws.lambda.pdf-ocr = {
    enable = mkBoolOpt false "Enable the Example Lambda Job";
    registry-name =
      mkOpt str "campground_ecr" "The name of the registry to use";
    variables = mkOpt (types.attrsOf types.str)
      {
        INPUT_BUCKET = "input-bucket-name";
        OUTPUT_BUCKET = "output-bucket-name"; # Target bucket for JSON results
      } "Environment Variables for the Lambda Function";
  };

  config = mkIf cfg.enable {
    aws = {
      storage.s3 = {
        enable = true;
        buckets = {
          "${cfg.variables.OUTPUT_BUCKET}" = { enable = true; };
          "${cfg.variables.INPUT_BUCKET}" = { enable = true; };
        };
      };
      lambda = {
        enable = true;
        jobs = {
          pdf-ocr = {
            lambda-image = pkgs.campground.aws-textract-job;
            registry-name = cfg.registry-name;
            environment.variables = cfg.variables;
            timeout = 600;
            depends_on = [
              "resource.aws_s3_bucket.${cfg.variables.INPUT_BUCKET}"
              "resource.aws_s3_bucket.${cfg.variables.OUTPUT_BUCKET}"
            ];
          };
        };
      };
    };

    data = {
      aws_iam_policy_document = {
        lambda_logging_policy = {
          statement = [{
            effect = "Allow";
            actions = [
              "logs:CreateLogGroup"
              "logs:CreateLogStream"
              "logs:PutLogEvents"
            ];
            resources = [ "arn:aws:logs:*:*:*" ];
          }];
        };

        lambda_policy = {
          statement = [
            # Allow S3 GetObject and PutObject permissions
            {
              effect = "Allow";
              actions = [ "s3:GetObject" "s3:PutObject" ];
              resources = [
                "arn:aws:s3:::${cfg.variables.INPUT_BUCKET}/*"
                "arn:aws:s3:::${cfg.variables.OUTPUT_BUCKET}/*"
              ];
            }

            # Allow Textract permissions
            {
              effect = "Allow";
              actions = [
                "textract:StartDocumentTextDetection"
                "textract:GetDocumentTextDetection"
                "textract:AnalyzeDocument" # Added permission
                "textract:GetAnalyzeDocument" # Optional
              ];
              resources = [ "*" ]; # Restrict to specific ARNs if possible
            }
          ];
        };
        # IAM Policy for Lambda Role
        s3_policy = {
          statement = [{
            effect = "Allow";
            actions = [ "s3:GetObject" "s3:PutObject" ];
            resources = [
              "arn:aws:s3:::${cfg.variables.INPUT_BUCKET}"
              "arn:aws:s3:::${cfg.variables.OUTPUT_BUCKET}/*"
            ];
          }];
        };
      };
    };

    resource = {
      # S3 Event Notification for Lambda Trigger
      aws_s3_bucket_notification.bucket_trigger = {
        bucket = cfg.variables.INPUT_BUCKET;
        lambda_function = [{
          lambda_function_arn =
            config.resource.aws_lambda_function.pdf-ocr "arn";
          events = [ "s3:ObjectCreated:*" ];
        }];
        depends_on = [ "aws_lambda_permission.allow_s3_trigger" ];
      };

      # Lambda Permission to Allow S3 Trigger
      aws_lambda_permission.allow_s3_trigger = {
        statement_id = "AllowS3Trigger";
        action = "lambda:InvokeFunction";
        function_name =
          config.resource.aws_lambda_function.pdf-ocr.function_name;
        principal = "s3.amazonaws.com";
        source_arn = "arn:aws:s3:::${cfg.variables.INPUT_BUCKET}";
      };
      aws_iam_role.iam_for_lambda = {
        name = "iam_for_lambda";
        assume_role_policy =
          config.data.aws_iam_policy_document.assume_role "json";
        depends_on = [ "resource.aws_iam_role.iam_for_lambda" ];
      };

      aws_iam_role_policy = {
        s3_access_policy = {
          name = "s3_access_policy";
          role = config.resource.aws_iam_role.iam_for_lambda.name;
          policy = config.data.aws_iam_policy_document.s3_policy "json";
          depends_on = [ "resource.aws_iam_role.iam_for_lambda" ];
        };

        logging_policy = {
          name = "logging_policy";
          role = config.resource.aws_iam_role.iam_for_lambda.name;
          policy =
            config.data.aws_iam_policy_document.lambda_logging_policy "json";
          depends_on = [ "resource.aws_iam_role.iam_for_lambda" ];
        };

        lambda_policy = {
          name = "lambda_policy";
          role = config.resource.aws_iam_role.iam_for_lambda.name;
          policy = config.data.aws_iam_policy_document.lambda_policy "json";
          depends_on = [ "resource.aws_iam_role.iam_for_lambda" ];
        };
      };
    };

  };
}
