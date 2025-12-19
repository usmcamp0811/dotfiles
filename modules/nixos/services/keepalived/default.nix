{ lib, config, pkgs, ... }:
with lib;
with lib.fmf;
let cfg = config.fmf.services.keepalived;
in {
  options.fmf.services.keepalived = {
    enable = lib.mkEnableOption "Enable KeepAliveD";
    instances = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          interface = lib.mkOption {
            type = lib.types.str;
            default = "eth1";
            description = "The interface name";
          };
          ips = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "The IPs to bind to";
          };
          state = lib.mkOption {
            type = lib.types.str;
            default = "MASTER";
            description = "State";
          };
          priority = lib.mkOption {
            type = lib.types.int;
            default = 50;
            description = "Priority";
          };
          virtualRouterId = lib.mkOption {
            type = lib.types.int;
            default = 50;
            description = "Virtual Router ID";
          };
        };
      });
      default = { };
      description = "KeepAliveD instances configuration.";
    };
  };

  config = lib.mkIf cfg.enable {
    networking.firewall.extraCommands = "iptables -A INPUT -p vrrp -j ACCEPT";
    services.keepalived.enable = true;
    services.keepalived.vrrpInstances = lib.mapAttrs'
      (name: instanceCfg:
        lib.nameValuePair name {
          interface = instanceCfg.interface;
          state = instanceCfg.state;
          priority = instanceCfg.priority;
          virtualIps = map (ip: { addr = ip; }) instanceCfg.ips;
          virtualRouterId = instanceCfg.virtualRouterId;
        })
      cfg.instances;
    environment.systemPackages = [ pkgs.tcpdump ];
  };
}
