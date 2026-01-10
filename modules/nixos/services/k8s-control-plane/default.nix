{ lib, config, pkgs, ... }:
with lib;
let
  cfg = config.campground.services.k8s-control-plane;
in {
  options.campground.services.k8s-control-plane = {
    enable = lib.mkEnableOption "Enable k8s control plane configuration";

    nodeId = lib.mkOption {
      type = lib.types.int;
      description = "Node ID (1, 2, or 3)";
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
  };

  config = lib.mkIf cfg.enable {
    # Calculate node-specific values based on nodeId
    # Node 1: MAC 50, IP 50, priority 100, MASTER
    # Node 2: MAC 53, IP 51, priority 90, BACKUP
    # Node 3: MAC 54, IP 52, priority 80, BACKUP

    microvm = {
      hypervisor = "qemu";
      writableStoreOverlay = "/nix/.rw-store";

      shares = [
        {
          proto = "virtiofs";
          tag = "ro-store";
          source = "/nix/store";
          mountPoint = "/nix/.ro-store";
        }
        {
          proto = "virtiofs";
          tag = "rw-store";
          source = "/persist/vm-stores/vm-k8s-control-${toString cfg.nodeId}/nix-store";
          mountPoint = "/nix/.rw-store";
        }
        {
          proto = "virtiofs";
          tag = "vault-agent";
          source = "/persist/system/var/lib/vault/vm-k8s-control-${toString cfg.nodeId}";
          mountPoint = "/var/lib/vault/vm-k8s-control-${toString cfg.nodeId}";
        }
        {
          proto = "virtiofs";
          tag = "k8s-data";
          source = "/persist/vm-data/vm-k8s-control-${toString cfg.nodeId}";
          mountPoint = "/var/lib/rancher";
        }
      ];

      interfaces = [
        {
          type = "tap";
          id = "vm-k8s-control-${toString cfg.nodeId}";
          # MAC addresses: 50, 53, 54 for nodes 1, 2, 3
          mac = "02:00:00:00:00:${if cfg.nodeId == 1 then "50" else if cfg.nodeId == 2 then "53" else "54"}";
        }
      ];

      vcpu = 4;
      mem = 4096;
      socket = "control.socket";
    };

    # Deterministic NIC name
    systemd.network.links."10-lan0" = {
      matchConfig.MACAddress = "02:00:00:00:00:${if cfg.nodeId == 1 then "50" else if cfg.nodeId == 2 then "53" else "54"}";
      linkConfig.Name = "lan0";
    };

    # Network configuration
    systemd.network.networks."20-lan0" = {
      matchConfig.Name = "lan0";
      networkConfig = {
        DHCP = "yes";
        IPv6AcceptRA = false;
      };
      linkConfig.RequiredForOnline = "routable";
    };

    networking.useNetworkd = true;
    networking.useDHCP = false;
    services.resolved.enable = false;

    networking.nameservers = [
      "10.8.0.2" # AdGuard
      "1.1.1.1"
      "8.8.8.8"
    ];

    # KeepAliveD configuration
    fmf.services.keepalived = {
      enable = true;
      instances.k8s-api = {
        interface = "lan0";
        ips = [cfg.vip];
        state = if cfg.nodeId == 1 then "MASTER" else "BACKUP";
        # Priority: 100, 90, 80 for nodes 1, 2, 3
        priority = 110 - (cfg.nodeId * 10);
        virtualRouterId = 49;
      };
    };

    # K3s configuration
    fmf.services.k3s = {
      enable = true;
      role = "server";
      clusterInit = cfg.nodeId == 1;
      serverAddr = "https://${cfg.vip}:6443";
      config = {
        disable = ["servicelb" "traefik"];
        cluster-init = cfg.nodeId == 1;
        server = if cfg.nodeId == 1 then null else "https://${cfg.vip}:6443";
        tls-san = [cfg.vip cfg.dnsSan] ++ cfg.nodeIps;
        node-name = "vm-k8s-control-${toString cfg.nodeId}";
      };
    };

    # Firewall
    networking.firewall = {
      enable = lib.mkForce true;
      allowedTCPPorts = [
        6443  # Kubernetes API
        10250 # Kubelet
        2379  # etcd client
        2380  # etcd peer
      ];
    };
  };
}
