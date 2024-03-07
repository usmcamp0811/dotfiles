{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
let
  cfg = config.campground.services.keepalived;
in
{
  options.campground.services.keepalived = with types; {
    enable = mkBoolOpt false "Enable KeepAliveD;";
    instanceName = mkOpt str "campground" "The instance Name";
    interface = mkOpt str "eth1" "The interface name";
    ip = mkOpt str "10.0.0.1" "The IP to bind to";
    state = mkOpt str "MASTER" "state";
    priority = mkOpt types.ints.between 1 255 50 "priority";
  };

  config = mkIf cfg.enable {
    networking.firewall.extraCommands = "iptables -A INPUT -p vrrp -j ACCEPT";
    services.keepalived.enable = true;
    services.keepalived.vrrpInstances.${cfg.instanceName} = {
      interface = cfg.interface;
      state = cfg.state;
      priority = cfg.priority;
      virtualIps = [{ addr = cfg.ip; }];
      virtualRouterId = 1;
    };
    environment.systemPackages = [ pkgs.tcpdump ];
  };
}
