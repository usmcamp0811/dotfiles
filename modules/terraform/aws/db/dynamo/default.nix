{ config, lib, pkgs, ... }:
with lib;
with lib.fmf;
with types;

let
  cfg = config.aws.db.dynamodb;
  tableOptions = types.submodule {
    options = {
      table_name = mkOpt str "example_table" "The name of the DynamoDB table.";

      attributes = mkOpt (listOf (attrsOf str)) [{
        name = "id";
        type = "S";
      }] "List of attributes for the DynamoDB table.";

      hash_key = mkOpt str "id" "The primary key of the table.";
      range_key =
        mkOpt (nullOr str) null "The range key of the table (optional).";
      read_capacity = mkOpt int 5 "Read capacity units.";
      write_capacity = mkOpt int 5 "Write capacity units.";
      autoscaling =
        mkBoolOpt false "Enable autoscaling for read/write capacity.";
    };
  };

in {
  options.aws.db.dynamodb = {
    enable = mkBoolOpt false "Enable AWS DynamoDB";
    tables = mkOpt (listOf tableOptions) [{ table_name = "default_table"; }]
      "List of DynamoDB tables.";
  };

  config = mkIf cfg.enable {
    resource.aws_dynamodb_table = mkMerge (map (table: {
      "${table.table_name}" = {
        name = table.table_name;
        hash_key = table.hash_key;
        range_key = table.range_key;
        billing_mode =
          if table.autoscaling then "PAY_PER_REQUEST" else "PROVISIONED";
        read_capacity = if table.autoscaling then null else table.read_capacity;
        write_capacity =
          if table.autoscaling then null else table.write_capacity;
        attribute = map (attr: {
          name = attr.name;
          type = attr.type;
        }) table.attributes;

        tags = { Environment = "production"; };
      };
    }) cfg.tables);
  };
}
