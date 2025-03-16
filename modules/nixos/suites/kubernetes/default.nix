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
    isLeader = mkOption {
      type = types.bool;
      default = false;
      description = ''
        The leader is used to generate the join tokens.
      '';
    };
    interface = mkOpt str "eno1" "Interface to use for the LAN Instance";
  };

  config = mkIf cfg.enable {
    campground.services = {
      k0s = {
        enable = true;
        package = pkgs.campground.k0s;
        isLeader = cfg.isLeader;
        role = cfg.role;
        apiAddress = "10.8.0.88";
        apiSans = [ "lucas" "daly" "10.8.0.88" "k8s-controller" ];
        clusterName = "campground";
        dataDir = "/var/lib/k0s";
      };
      keepalived = mkIf (cfg.role == "controller") {
        enable = true;
        instances = {
          "k8s-proxy" = {
            interface = cfg.interface;
            ips = [ "10.8.0.88" ];
            state = "MASTER";
            priority = 35;
            virtualRouterId = 59;
          };
        };
      };
      haproxy = mkIf (cfg.role == "controller") {
        enable = true;
        frontend-ip = "0.0.0.0";
        frontend-port = "8443";
        defaults = {
          mode = "tcp";
          "timeout connect" = "5s";
          "timeout client" = "50s";
          "timeout server" = "50s";
        };
        # TODO: make function to get the host names
        backendServers = lookupK0sControllers {
          nixosConfigurations = inputs.self.nixosConfigurations;
        };
        # {
        #   "lucas" = { port = 6443; };
        #   "daly" = { port = 6443; };
        #   "ermy" = { port = 6443; };
        # };
      };
    };
  };
}
