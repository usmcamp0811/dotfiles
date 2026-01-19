{
  lib,
  config,
  pkgs,
  ...
}:
with lib; let
  cfg = config.fmf.services.k8s-control-plane;
in {
  options.fmf.services.k8s-control-plane = {
    enable = lib.mkEnableOption "Enable k8s control plane configuration";

    nodeId = lib.mkOption {
      type = lib.types.int;
      description = "Node ID (0, 1, or 2)";
    };

    interface = lib.mkOption {
      type = lib.types.str;
      default = "lan0";
      description = "Network interface to use";
    };

    vip = lib.mkOption {
      type = lib.types.str;
      default = "10.8.40.49";
      description = "Virtual IP for k8s API";
    };

    nodeIps = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = ["10.8.40.50" "10.8.40.51" "10.8.40.52"];
      description = "IPs of all control plane nodes";
    };

    dnsSan = lib.mkOption {
      type = lib.types.str;
      default = "k8s-api.lan.aicampground.com";
      description = "DNS name for k8s API";
    };

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/rancher";
      description = "Data directory for k3s";
    };

    disabledServices = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = ["servicelb" "traefik"];
      description = "K3s services to disable";
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
    # Calculate node-specific values based on nodeId
    # Node 0: priority 110, MASTER
    # Node 1: priority 100, BACKUP
    # Node 2: priority 90, BACKUP

    # Deterministic NIC name (only if MAC address is provided)
    systemd.network.links."10-${cfg.interface}" = lib.mkIf (cfg.macAddress != null) {
      matchConfig.MACAddress = cfg.macAddress;
      linkConfig.Name = cfg.interface;
    };

    # Network configuration
    systemd.network.networks."20-${cfg.interface}" = {
      matchConfig.Name = cfg.interface;
      networkConfig = {
        DHCP =
          if cfg.useDHCP
          then "yes"
          else "no";
        IPv6AcceptRA = false;
      };
      linkConfig.RequiredForOnline = "routable";
    };

    networking.useNetworkd = cfg.useNetworkd;
    networking.useDHCP = false;
    services.resolved.enable = false;

    networking.nameservers = cfg.nameservers;

    # KeepAliveD configuration
    fmf.services.keepalived = {
      enable = true;
      instances.k8s-api = {
        interface = cfg.interface;
        ips = [cfg.vip];
        state =
          if cfg.nodeId == 0
          then "MASTER"
          else "BACKUP";
        # Priority: 110, 100, 90 for nodes 0, 1, 2
        priority = 110 - (cfg.nodeId * 10);
        virtualRouterId = 49;
      };
    };

    # K3s configuration
    fmf.services.k3s = {
      enable = true;
      role = "server";
      clusterInit = cfg.nodeId == 0;
      serverAddr = cfg.vip;
      snapshotter = cfg.snapshotter;
      config = {
        disable = cfg.disabledServices;
        server =
          if cfg.nodeId == 0
          then null
          else "https://${cfg.vip}:6443";
        tls-san = [cfg.vip cfg.dnsSan] ++ cfg.nodeIps;
        node-name = "k8s-control-${toString cfg.nodeId}";
        data-dir = cfg.dataDir;
      };
    };

    # Firewall
    networking.firewall = {
      enable = lib.mkForce true;
      allowedTCPPorts = [
        6443 # Kubernetes API
        10250 # Kubelet
        2379 # etcd client
        2380 # etcd peer
      ];
    };
  };
}
