{ lib, config, pkgs, ... }:
with lib;
let
  cfg = config.campground.services.keepalived;
in
{
  options.campground.services.keepalived = with types; {
    enable = mkEnableOption "Enable KeepAliveD";
    instances = mkOption {
      type = attrsOf (submodule {
        options = {
          instanceName = mkOption { type = str; default = "campground"; description = "The instance Name"; };
          interface = mkOption { type = str; default = "eth1"; description = "The interface name"; };
          ips = mkOption { type = listOf str; default = []; description = "The IPs to bind to"; };
          state = mkOption { type = str; default = "MASTER"; description = "State"; };
          priority = mkOption { type = int; default = 50; description = "Priority"; };
          virtualRouterId = mkOption { type = int; default = 50; description = "Virtual Router ID"; };
        };
      });
      default = {};
      description = "KeepAliveD instances configuration.";
    };
  };

  config = mkIf cfg.enable {
    networking.firewall.extraCommands = "iptables -A INPUT -p vrrp -j ACCEPT";
    services.keepalived.enable = true;
    services.keepalived.vrrpInstances = mapAttrs' (name: instanceCfg: nameValuePair name {
      interface = instanceCfg.interface;
      state = instanceCfg.state;
      priority = instanceCfg.priority;
      virtualIps = map (ip: { addr = ip; }) instanceCfg.ips;
      virtualRouterId = instanceCfg.virtualRouterId;
    }) cfg.instances;
    environment.systemPackages = [ pkgs.tcpdump ];
  };
}

