{ lib, config, pkgs, ... }:
with lib;
let
  cfg = config.campground.services.keepalived;
  createVrrpInstance = instance: {
    inherit (instance) interface state priority virtualRouterId;
    virtualIps = map (ip: { addr = ip; }) instance.ips;
  };
in
{
  options.campground.services.keepalived = {
    enable = mkEnableOption "KeepAliveD";
    instances = mkOption {
      type = types.listOf (types.submodule {
        options = {
          instanceName = mkOption {
            type = types.str;
            description = "The instance name.";
          };
          interface = mkOption {
            type = types.str;
            default = "eth1";
            description = "The interface name.";
          };
          ips = mkOption {
            type = types.listOf types.str;
            example = [ "10.0.0.1" ];
            description = "The IPs to bind to.";
          };
          state = mkOption {
            type = types.str;
            default = "MASTER";
            description = "State.";
          };
          priority = mkOption {
            type = types.ints.between 1 255;
            default = 50;
            description = "Priority.";
          };
          virtualRouterId = mkOption {
            type = types.int;
            description = "Virtual router ID.";
          };
        };
      });
      description = "KeepAliveD instances.";
    };
  };

  config = mkIf cfg.enable {
    networking.firewall.extraCommands = "iptables -A INPUT -p vrrp -j ACCEPT";
    services.keepalived.enable = true;
    services.keepalived.vrrpInstances = lib.flip lib.attrsets.mapAttrs' (name: instance: {
      inherit name;
      value = createVrrpInstance instance;
    }) cfg.instances;
    environment.systemPackages = [ pkgs.tcpdump ];
  };
}

