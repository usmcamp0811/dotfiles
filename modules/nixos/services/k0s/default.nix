{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
let
  cfg = config.campground.services.k0s;
  inherit (pkgs.campground) k0s;
  k0sConfig = pkgs.writeText "k0s.yaml" ''
  # generated-by-k0sctl 2023-04-24T20:51:01-05:00
  apiVersion: k0s.k0sproject.io/v1beta1
  kind: ClusterConfig
  spec:
    api:
      address: 10.8.0.135
      sans:
      - 10.8.0.135
      - 10.8.0.161
    network:
      nodeLocalLoadBalancing:
        enabled: true
        type: EnvoyProxy
      podCIDR: 10.244.0.0/16
      provider: kuberouter
      serviceCIDR: 10.96.0.0/12
    telemetry:
      enabled: false
'';
in
{
  options.campground.services.k0s = with types; {
    enable = mkBoolOpt false "Enable k0s;";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      k0s
      k0sctl
    ];

    systemd.services.k0sworker = {
      description = "k0s - Zero Friction Kubernetes";
      documentation = [ "https://docs.k0sproject.io" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.campground.k0s}/bin/k0s worker --token-file=/config/workertoken";
        Restart = "always";
      };
      wantedBy = [ "multi-user.target" ];
    };
    services.kubernetes = {
      roles = ["master" "node"];
      masterAddress = "10.8.0.161";
      flannel = {
        enable = true;
      };
    };
    # services.openiscsi.enable = true;


    # systemd.services.k0scontroller = {
    #   description = "k0s - The Zero Friction Kubernetes";
    #   documentation = [ "https://docs.k0sproject.io" ];
    #   path = with pkgs; [
    #     util-linux # required by kubelet: https://github.com/k0sproject/k0s/issues/3386
    #   ];
    #   after = [ "network-online.target" ];
    #   wants = [ "network-online.target" ];
    #   wantedBy = [ "multi-user.target" ];
    #   serviceConfig = {
    #     ExecStart = "${k0s}/bin/k0s controller --config=${k0sConfig} --data-dir=/var/lib/k0s --single=true";
    #   };
    # };
  };
}
