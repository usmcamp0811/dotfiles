{ options, config, lib, pkgs, ... }:
with lib;
with lib.campground;
let cfg = config.campground.suites.kubernetes;
in {
  options.campground.suites.kubernetes = with types; {
    enable =
      mkBoolOpt false "Whether or not to enable kubernetes configuration.";
    role = mkOption {
      type = types.enum [ "controller" "controller+worker" "worker" "single" ];
      default = "single";
      description = ''
        K8s role.
      '';
    };
  };

  config = mkIf cfg.enable {
    campground.services = {
      k0s = {
        enable = true;
        package = pkgs.campground.k0s;
        role = cfg.role;
        apiAddress = "10.8.0.1";
        apiSans = [ "lucas" "campnet" ];
        clusterName = "campground";
        isLeader = false; # Set this to true on the initial controller node
        dataDir = "/var/lib/k0s";
      };
    };
  };
}
