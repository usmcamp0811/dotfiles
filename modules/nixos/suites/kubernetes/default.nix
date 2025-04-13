{ options
, config
, lib
, pkgs
, inputs
, ...
}:
with lib;
with lib.campground; let
  cfg = config.campground.suites.kubernetes;

  kubeAPIPort = 6443;
  konnectivityPort = 8132;
  controllerJoinAPIPort = 9445;
  k8sIP = "10.8.0.88";

  controllers = lookupK0sControllers {
    nixosConfigurations = inputs.self.nixosConfigurations;
  };
  kubeApi = lookupK0sControllers {
    nixosConfigurations = inputs.self.nixosConfigurations;
    port = kubeAPIPort;
  };
  k0scontrollers = lookupK0sControllers {
    nixosConfigurations = inputs.self.nixosConfigurations;
    port = controllerJoinAPIPort;
  };
  konnectivity = lookupK0sControllers {
    nixosConfigurations = inputs.self.nixosConfigurations;
    port = konnectivityPort;
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
        interface = cfg.interface;
        isLeader = cfg.isLeader;
        role = cfg.role;
        apiAddress = "10.8.0.1";
        apiSans =
          [ "10.8.0.1" ]
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
            ips = [ k8sIP ]; # Virtual IP for HA
            state = "MASTER";
            priority = 35;
            virtualRouterId = 59;
          };
        };
      };

      haproxy = mkIf (cfg.role == "worker") {
        enable = true;
        stats.enable = true;
        defaults = {
          mode = "tcp";
          "timeout connect" = "5s";
          "timeout client" = "50s";
          "timeout server" = "50s";
        };
        frontends = {
          "kubeAPI" = {
            bind = [ "${k8sIP}:${toString kubeAPIPort}" ];
            backend = "kubeAPI_backend";
            options = [ "option tcplog" ];
          };
          "konnectivity" = {
            bind = [ "${k8sIP}:${toString konnectivityPort}" ];
            backend = "konnectivity_backend";
            options = [ "option tcplog" ];
          };
          "controllerJoinAPI" = {
            bind = [ "${k8sIP}:${toString controllerJoinAPIPort}" ];
            backend = "controllerJoinAPI_backend";
            options = [ "option tcplog" ];
          };
        };
        backends = {
          "kubeAPI_backend" = {
            balance = "leastconn";
            servers = kubeApi;
            options = [
              "mode tcp"
              "option tcp-check"
              "tcp-check connect"
            ];
          };
          "konnectivity_backend" = {
            balance = "leastconn";
            servers = konnectivity;
            options = [
              "mode tcp"
              "option tcp-check"
              "tcp-check connect"
            ];
          };
          "controllerJoinAPI_backend" = {
            balance = "leastconn";
            servers = k0scontrollers;
            options = [
              "mode tcp"
              "option tcp-check"
              "tcp-check connect"
            ];
          };
        };
      };
    };
  };
}
