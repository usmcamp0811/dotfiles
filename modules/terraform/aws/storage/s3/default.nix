{ config, lib, pkgs, ... }:
with lib;
with lib.campground;
with types;

let
  cfg = config.aws.storage.s3;
  loggingOptions = types.submodule {
    options = {
      target_bucket = mkOpt str null "Target bucket for logging";
      target_prefix = mkOpt str null "Prefix for logging";
    };
  };
  bucketOptions = types.submodule {
    options = {
      enable = mkBoolOpt true "Enable or disable the bucket";
      tags = mkOpt (attrsOf str) { } "Custom tags for the bucket";
      force_destroy = mkBoolOpt false "Force destroy on deletion";

      logging = mkOpt (nullOr loggingOptions) null "Logging configuration";
      ipWhiteList = mkOpt (listOf str) cfg.defaultIpWhiteList
        "IPs to whitelist for the bucket";
    };
  };
in
{
  options.aws.storage.s3 = {
    enable = mkBoolOpt false "Enable S3 Buckets management";
    buckets = mkOpt (attrsOf bucketOptions) { }
      "Attribute set of S3 Buckets, keyed by bucket name";
    defaultIpWhiteList =
      mkOpt (listOf str) [ "0.0.0.0/0" ] "List of IPs to whitelist";
    defaultTags = mkOpt (attrsOf str)
      {
        project = "Campground-DefaultAWS";
        environment = "dev";
        createdBy = "Terranix";
      } "Default tags for all buckets";
  };

  config = mkIf cfg.enable {

    resource.aws_s3_bucket = builtins.listToAttrs (map
      (bucketName: {
        name = bucketName;
        value = {
          bucket = bucketName;
          tags = cfg.defaultTags // (cfg.buckets.${bucketName}.tags or { });
          force_destroy = cfg.buckets.${bucketName}.force_destroy or false;

          # Assign logging configuration only when explicitly defined
          logging =
            if cfg.buckets.${bucketName}.logging != null then {
              inherit (cfg.buckets.${bucketName}.logging)
                target_bucket target_prefix;
            } else
              null;
        };
      })
      (attrNames cfg.buckets));

    resource.aws_s3_bucket_policy = builtins.listToAttrs (map
      (bucketName: {
        name = "${bucketName}_policy";
        value = {
          bucket = bucketName;
          policy = builtins.toJSON {
            Version = "2012-10-17";
            Statement = [{
              Effect = "Allow";
              Principal = "*";
              Action = "s3:GetObject";
              Resource = "arn:aws-us:s3:::${bucketName}/*";
              Condition = {
                IpAddress = {
                  "aws:SourceIp" = cfg.buckets.${bucketName}.ipWhiteList or [ ];
                };
              };
            }];
          };
          depends_on = [ "aws_s3_bucket.${bucketName}" ];
        };
      })
      (attrNames cfg.buckets));
  };
}
