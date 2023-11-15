{ options, config, pkgs, lib, ... }:

with lib;
with lib.campground;
let cfg = config.campground.nfs.mlflow-artifacts;
in
{
  options.campground.nfs.mlflow-artifacts = with types; {
    enable = mkBoolOpt false "Whether or not to mount mlflow-artifacts.";
  };

  config = mkIf cfg.enable {
    fileSystems."/mnt/mlflow-artifacts" = {
      device = "webb:/var/lib/mlflow/artifacts";
      fsType = "nfs";
      options = [ "rw" "soft" ];
    };
  };
}
