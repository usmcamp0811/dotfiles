{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
let
  cfg = config.campground.services.k0s;
  inherit (pkgs.campground) k0s;
in
{
  options.campground.services.k0s = with types; {
    enable = mkBoolOpt false "Enable k0s;";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      k0s
      k0sctl
      openiscsi
      cni-plugins
      cni-plugin-flannel
      calico-cni-plugin
    ];

    security.apparmor.enable = true;

    environment.etc."cni/net.d/10-flannel.conflist".text = ''
      {
        "name": "cbr0",
        "cniVersion": "0.3.1",
        "plugins": [
          {
            "type": "flannel",
            "delegate": {
              "hairpinMode": true,
              "isDefaultGateway": true
            }
          },
          {
            "type": "portmap",
            "capabilities": {
              "portMappings": true
            }
          }
        ]
      }
    '';

    environment.etc."cni/net.d/10-kuberouter.conflist".text = ''
      {"cniVersion":"0.3.0","name":"mynet","plugins":[{"auto-mtu":true,"bridge":"kube-bridge","hairpinMode":true,"ipMasq":false,"ipam":{"subnet":"10.244.2.0/24","type":"host-local"},"isDefaultGateway":true,"mtu":1500,"name":"kubernetes","type":"bridge"},{"capabilities":{"portMappings":true,"snat":true},"mtu":1500,"type":"portmap"}]}
    '';
    systemd.services.k0sworker = {
      description = "k0s - Zero Friction Kubernetes";
      documentation = [ "https://docs.k0sproject.io" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.campground.k0s}/bin/k0s worker --token-file=/config/workertoken";
        Restart = "always";
        Environment = "PATH=/run/wrappers/bin/:$PATH";  # Add this line

      };
      wantedBy = [ "multi-user.target" ];
    };
    services.openiscsi.enable = true;
    services.openiscsi.name = "daly";
  };
}
