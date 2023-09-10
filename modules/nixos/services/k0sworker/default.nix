{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
let
  cfg = config.campground.services.k0sworker;
  inherit (pkgs.campground) k0s;
in
{
  options.campground.services.k0sworker = with types; {
    enable = mkBoolOpt false "Enable k0sworker;";

    role-id = mkOpt str config.campground.services.vault-agent.settings.vault.role-id "Absolute path to the Vault role-id";
    secret-id = mkOpt str config.campground.services.vault-agent.settings.vault.secret-id "Absolute path to the Vault secret-id";
    vault-path = mkOpt str "secret/campground/k0s" "The Vault path to the KV containing the k0s secrets.";
    vault-address = mkOption {
      type = str;
      default = config.campground.services.vault-agent.settings.vault.address;
      description = "The address of your Vault";
    };
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

    systemd.services.flannel-subnet-env = {
      description = "Create /run/flannel/subnet.env";
      script = ''
        mkdir -p /run/flannel/
        echo "FLANNEL_NETWORK=10.244.0.0/16" > /run/flannel/subnet.env
        echo "FLANNEL_SUBNET=10.244.2.1/24" >> /run/flannel/subnet.env
        echo "FLANNEL_MTU=1450" >> /run/flannel/subnet.env
        echo "FLANNEL_IPMASQ=true" >> /run/flannel/subnet.env
      '';
      serviceConfig = {
        Type = "oneshot";
      };
    };

    systemd.services.k0sworker = {
      description = "k0s - Zero Friction Kubernetes";
      documentation = [ "https://docs.k0sproject.io" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.campground.k0s}/bin/k0s worker --token-file=/tmp/detsys-vault/worker-token";
        Restart = "always";
        Environment = "PATH=${pkgs.openiscsi}/bin:/run/wrappers/bin:$PATH";


      };
      wantedBy = [ "multi-user.target" ];
    };
    services.openiscsi = {
      enable = true;
      name = "iqn.2016-04.com.open-iscsi:${config.system.name}";
    };

    campground.services.vault-agent.services.k0sworker = {
      settings = {
        vault.address = cfg.vault-address;
        auto_auth = {
          method = [{
            type = "approle";
            config = {
              role_id_file_path = cfg.role-id;
              secret_id_file_path = cfg.secret-id;
              remove_secret_id_file_after_reading = false;
            };
          }];
        };
      };
      secrets = {
        file = {
          files = {
            "worker-token" = {
              text = ''{{ with secret "${cfg.vault-path}" }}{{ .Data.worker }}{{ end }}'';
              permissions = "0400";  # Make the script executable
              change-action = "restart";
            };
          };
        };
      };
    };
  };
}
