{ options, config, lib, pkgs, inputs, ... }:
with lib;
with lib.campground;
let
  cfg = config.campground.suites.kubernetes;
  controllers = lookupK0sControllers {
    nixosConfigurations = inputs.self.nixosConfigurations;
  };

in
{
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
        apiSans = [ "10.8.0.88" "k8s-controller" ]
          ++ builtins.attrNames controllers;
        clusterName = "campground";
        dataDir = "/var/lib/k0s";
      };

      # Move HAProxy and Keepalived to worker nodes
      keepalived = mkIf (cfg.role == "worker") {
        enable = true;
        instances = {
          "k8s-proxy" = {
            interface = cfg.interface;
            ips = [ "10.8.0.88" ]; # Virtual IP for HA
            state = "MASTER";
            priority = 35;
            virtualRouterId = 59;
          };
        };
      };

      haproxy = mkIf (cfg.role == "worker") {
        enable = true;
        defaults = {
          mode = "tcp";
          "timeout connect" = "5s";
          "timeout client" = "50s";
          "timeout server" = "50s";
        };
        frontends = {
          "k8s-api" = {
            bind = [ "*:6443" ];
            backend = "kube-masters";
            options = [ "option tcplog" ];
          };
        };
        backends = {
          "kube-masters" = {
            balance = "leastconn";
            servers = {
              "daly" = {
                ip = "daly";
                port = 6443;
                options = [ "check" ];
              };
              "ermy" = {
                ip = "ermy";
                port = 6443;
                options = [ "check" ];
              };
              "lucas" = {
                ip = "lucas";
                port = 6443;
                options = [ "check" ];
              };
            };
          };
        };
      };
    };
  };
}
