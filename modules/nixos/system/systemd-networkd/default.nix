{
  options,
  config,
  lib,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.system.systemd-networkd;
in {
  options.fmf.system.systemd-networkd = with types; {
    enable = mkBoolOpt false "Whether or not to enable systemd-networkd for network management";

    bridge = {
      enable = mkBoolOpt false "Whether to create a bridge for virtual machines";
      name = mkOpt str "br-vm" "Name of the bridge interface";
      interface = mkOpt (nullOr str) null "Primary network interface to bridge (e.g., eno1)";
      address = mkOpt (nullOr str) null "Static IP address for the bridge (e.g., 10.8.0.194/24)";
      gateway = mkOpt (nullOr str) null "Default gateway (e.g., 10.8.0.1)";
      dns = mkOpt (listOf str) ["1.1.1.1" "8.8.8.8"] "DNS servers";
    };
  };

  config = mkIf cfg.enable {
    # Enable systemd-networkd and disable DHCP/NetworkManager
    networking.useNetworkd = true;
    networking.useDHCP = false;
    networking.dhcpcd.enable = false;
    networking.networkmanager.enable = lib.mkForce false;

    # Disable systemd-networkd wait-online to prevent boot delays
    systemd.services.systemd-networkd-wait-online.enable = false;

    # Bridge configuration (if enabled)
    systemd.network = mkIf cfg.bridge.enable {
      # Create the bridge device
      netdevs."10-${cfg.bridge.name}" = {
        netdevConfig = {
          Kind = "bridge";
          Name = cfg.bridge.name;
        };
      };

      # Configure the bridge network
      networks."20-${cfg.bridge.name}" = {
        matchConfig.Name = cfg.bridge.name;
        address = mkIf (cfg.bridge.address != null) [cfg.bridge.address];
        gateway = mkIf (cfg.bridge.gateway != null) [cfg.bridge.gateway];
        dns = cfg.bridge.dns;
        networkConfig = {
          DHCP = "no";
          IPv6AcceptRA = false;
        };
        linkConfig.RequiredForOnline = "routable";
      };

      # Bridge the primary interface (if specified)
      networks."10-${cfg.bridge.interface}" = mkIf (cfg.bridge.interface != null) {
        matchConfig.Name = cfg.bridge.interface;
        networkConfig = {
          Bridge = cfg.bridge.name;
          DHCP = "no";
        };
      };

      # Auto-connect VM tap interfaces to the bridge
      networks."30-vm-taps" = {
        matchConfig.Name = "vm-*";
        networkConfig.Bridge = cfg.bridge.name;
        linkConfig.RequiredForOnline = "enslaved";
      };
    };
  };
}
