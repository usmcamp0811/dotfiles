{ config, lib, pkgs, ... }:
with lib;
with lib.cyclops;
with types;

let
  cfg = config.aws.storage.ecr;
  registryOptions = types.submodule {
    options = {
      name = mkOpt str "ecr-registry" "ECR Name";
      image_tag_mutability =
        mkOpt str "MUTABLE" "Mutable tags or not mutable tags";
      scan_on_push = mkBoolOpt true "Enable scanning on push";
      force_delete = mkBoolOpt true "Delete images if destroyed";
    };
  };
in {
  options.aws.storage.ecr = {
    enable = mkBoolOpt false "Enable AWS Elastic Container Registry";
    registeries = mkOpt (listOf registryOptions) [{ name = "default-ecr"; }]
      "List of Registries";
  };

  config = mkIf cfg.enable {
    resource.aws_ecr_repository = mkMerge (map (registery: {
      "${registery.name}" = {
        inherit (registery) name image_tag_mutability;
        image_scanning_configuration = {
          scan_on_push = registery.scan_on_push;
        };
        force_delete = registery.force_delete;
      };
    }) cfg.registeries);

    resource.aws_ecr_lifecycle_policy = mkMerge (map (registery: {
      "${registery.name}" = {
        repository = registery.name;
        depends_on = [ "resource.aws_ecr_repository.${registery.name}" ];
        policy = builtins.toJSON {
          rules = [{
            rulePriority = 1;
            description = "Keep only 10 images";
            selection = {
              countType = "imageCountMoreThan";
              countNumber = 10;
              tagStatus = "tagged";
              tagPrefixList = [ "prod" ];
            };
            action = { type = "expire"; };
          }];
        };
      };
    }) cfg.registeries);
  };
}
