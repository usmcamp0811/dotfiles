{
  lib,
  config,
  pkgs,
  ...
}:
with lib; let
  cfg = config.fmf.services.k8s-worker;
in {
  options.fmf.services.k8s-worker = {
    enable = lib.mkEnableOption "Enable k8s worker node configuration";

    nodeName = lib.mkOption {
      type = lib.types.str;
      default = config.networking.hostName;
      description = "Node name for the worker";
    };

    interface = lib.mkOption {
      type = lib.types.str;
      default = "lan0";
      description = "Network interface to use";
    };

    serverUrl = lib.mkOption {
      type = lib.types.str;
      default = "10.8.40.49";
      description = "K8s control plane IP or hostname (without https:// or port)";
    };

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/rancher";
      description = "Data directory for k3s";
    };

    macAddress = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "MAC address for the network interface (optional, for VMs)";
    };

    nameservers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = ["10.8.0.2" "1.1.1.1" "8.8.8.8"];
      description = "DNS nameservers";
    };

    useNetworkd = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Use systemd-networkd";
    };

    useDHCP = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Use DHCP for network configuration";
    };

    extraK3sConfig = lib.mkOption {
      type = lib.types.attrs;
      default = {};
      description = "Extra K3s agent configuration options";
    };

    snapshotter = lib.mkOption {
      type = lib.types.nullOr (lib.types.enum ["overlayfs" "fuse-overlayfs" "native"]);
      default = null;
      description = ''
        Container snapshotter to use. Set to "fuse-overlayfs" for virtiofs compatibility (e.g., MicroVMs).
        If null, k3s will use its default (overlayfs).
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # Deterministic NIC name (only if MAC address is provided)
    systemd.network.links."10-${cfg.interface}" = lib.mkIf (cfg.macAddress != null) {
      matchConfig.MACAddress = cfg.macAddress;
      linkConfig.Name = cfg.interface;
    };

    # Network configuration
    systemd.network.networks."20-${cfg.interface}" = {
      matchConfig.Name = cfg.interface;
      networkConfig = {
        DHCP = if cfg.useDHCP then "yes" else "no";
        IPv6AcceptRA = false;
      };
      linkConfig.RequiredForOnline = "routable";
    };

    networking.useNetworkd = cfg.useNetworkd;
    networking.useDHCP = false;
    services.resolved.enable = false;

    networking.nameservers = cfg.nameservers;

    # K3s worker configuration
    fmf.services.k3s = {
      enable = true;
      role = "agent";
      serverAddr = cfg.serverUrl;
      snapshotter = cfg.snapshotter;
      config = {
        node-name = cfg.nodeName;
        data-dir = cfg.dataDir;
      } // cfg.extraK3sConfig;
    };

    # Firewall - K3s worker node requirements
    networking.firewall = {
      enable = lib.mkForce true;

      # Trust Kubernetes networking interfaces for pod-to-pod communication
      trustedInterfaces = ["cni0" "flannel.1"];

      # Required TCP ports for worker nodes
      allowedTCPPorts = [
        10250 # Kubelet metrics
      ];

      # NodePort services range (allows external traffic to NodePort services)
      allowedTCPPortRanges = [
        {
          from = 30000;
          to = 32767;
        }
      ];

      # VXLAN traffic for Flannel overlay network (cross-node pod communication)
      allowedUDPPorts = [8472];
    };
  };
}
