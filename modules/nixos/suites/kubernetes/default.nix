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
      keepalived = {
        enable = true;
        instances = {
          "k8s-proxy" = {
            interface = "eno1";
            ips = [ "10.8.0.88" ];
            state = "MASTER";
            priority = 50;
            virtualRouterId = 52;
          };
        };
      };
      haproxy = {
        enable = true;
        frontend-ip = "10.8.0.88";
        frontend-port = "6443";
        defaults = {
          mode = "tcp";
          "timeout connect" = "5s";
          "timeout client" = "50s";
          "timeout server" = "50s";
        };
        backendServers = {
          "lucas" = { port = 6443; };
          "chesty" = { port = 6443; };
        };
      };
    };
  };
}
