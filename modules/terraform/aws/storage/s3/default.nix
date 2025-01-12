{ config, lib, pkgs, ... }:
with lib;
with lib.campground;
with types;

let cfg = config.aws.storage.s3;
in {
  options.aws.storage.s3 = {
    enable = mkBoolOpt false "Enable S3Buckets";
    region = mkOpt str "us-east-1" "Region for all buckets";
    ip-white-list = mkOpt (listOf str) [ "0.0.0.0/0" ] "Allowed IPs";
    tags = mkOpt (attrsOf str)
      {
        project = "Campground";
        environment = "dev";
        "created-by" = "Terranix";
      } "Default tags for all buckets";
    buckets = mkOpt (listOf str) [ ] "A list of bucket names.";
  };

  config = mkIf cfg.enable {
    provider.aws.region = cfg.region;
    provider.aws.default_tags.tags = cfg.tags;

    # Manage S3 buckets
    resource.aws_s3_bucket = builtins.listToAttrs (map
      (bucket: {
        name = bucket;
        value = {
          bucket = bucket;
          tags = cfg.tags;
        };
      })
      cfg.buckets);

    # Add bucket policies
    resource.aws_s3_bucket_policy = builtins.listToAttrs (map
      (bucket: {
        name = "${bucket}_policy";
        value = {
          bucket = bucket;
          policy = builtins.toJSON {
            Version = "2012-10-17";
            Statement = [{
              Effect = "Allow";
              Principal = "*";
              Action = "s3:GetObject";
              Resource = "arn:aws-us:s3:::${bucket}/*";
              Condition = {
                IpAddress = { "aws:SourceIp" = cfg.ip-white-list; };
              };
            }];
          };
          depends_on = [ "aws_s3_bucket.${bucket}" ];
        };
      })
      cfg.buckets);
  };
}
