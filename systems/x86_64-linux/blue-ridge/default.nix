{
  lib,
  pkgs,
  ...
}:
with lib;
with lib.campground; {
  imports = [
    ./hardware.nix
    ./impermanence.nix
  ];

  # System metadata
  networking.hostName = "blue-ridge";
  time.timeZone = "America/New_York";

  # Locale
  i18n.defaultLocale = "en_US.UTF-8";
  console = {
    font = "Lat2-Terminus16";
    keyMap = "us";
  };

  crystal-forge.stig-presets.off.enable = true;
  campground = {
    # User configuration
    user = {
      name = "admin";
      fullName = "Router Administrator";
      email = "admin@blue-ridge.local";
      extraGroups = ["wheel" "networkmanager"];
      uid = 1000;
    };

    # Router configuration using campground modules
    router = {
      # enable = true;
      wan = {
        interface = "enp1s0"; # First port - WAN
        dhcp = true; # Get IP from ISP
        # staticIP = "203.0.113.10/24"; # Uncomment if you have static IP from ISP
      };

      lan = {
        interfaces = ["enp2s0" "enp3s0" "enp4s0"]; # Remaining 3 ports - LAN
        subnet = "192.168.1.0/24";
        gateway = "192.168.1.1";
      };

      enableIPv6 = false; # Enable if your ISP provides IPv6

      dns = {
        forwarders = [
          "1.1.1.1"
          "1.0.0.1"
          "8.8.8.8"
          "8.8.4.4"
        ];
        enableDNSSEC = true;
      };

      firewall = {
        allowPing = false; # Don't respond to WAN pings
        extraRules = ''
          # Example: Port forward SSH from WAN to internal server
          # table inet nat {
          #   chain prerouting {
          #     iifname "enp1s0" tcp dport 2222 dnat to 192.168.1.100:22
          #   }
          # }
        '';
      };

      # DHCP Configuration
      dhcp = {
        enable = true;
        poolStart = "192.168.1.100";
        poolEnd = "192.168.1.250";
        leaseTime = 86400; # 24 hours

        # Static DHCP leases - easy to manage!
        staticLeases = [
          # Example static leases - customize these
          # {
          #   hostname = "desktop";
          #   mac = "00:11:22:33:44:55";
          #   ip = "192.168.1.10";
          #   description = "Main desktop computer";
          # }
          # {
          #   hostname = "nas";
          #   mac = "AA:BB:CC:DD:EE:FF";
          #   ip = "192.168.1.20";
          #   description = "Network storage";
          # }
          # {
          #   hostname = "printer";
          #   mac = "11:22:33:44:55:66";
          #   ip = "192.168.1.30";
          #   description = "Network printer";
          # }
        ];
      };

      # Security hardening
      security = {
        enable = true;

        enableSSH = true;
        sshPort = 22;

        enableWebUI = false; # Not implemented yet

        fail2ban = {
          enable = true;
          maxRetry = 3;
          banTime = 3600; # 1 hour
        };

        # Additional services if needed
        # allowedServices = [
        #   {
        #     port = 8080;
        #     protocol = "tcp";
        #     interface = "br-lan";
        #   }
        # ];
      };
    };

    # Services
    services = {
      # Disable LDAP client (not needed for router)
      ldap-client = {enable = mkForce false;};

      # Optional: Enable if you want to monitor the router
      # netbird.client = enabled;
    };
  };

  # Disable NetworkManager - using systemd-networkd via router module
  # networking.networkmanager.enable = mkForce false;
  # networking.useDHCP = mkForce false;

  # Firewall - managed by router module
  networking.firewall.enable = mkForce false; # Using nftables from router module

  # Enable monitoring tools (optional)
  services.prometheus = {
    enable = false; # Enable if you want metrics
    exporters = {
      node = {
        enable = false;
        enabledCollectors = ["systemd"];
        port = 9100;
      };
    };
  };

  # Logging
  services.journald.extraConfig = ''
    SystemMaxUse=500M
    MaxRetentionSec=7day
  '';

  # NTP for time sync
  services.timesyncd.enable = true;

  # Minimal packages (router module provides base set)
  environment.systemPackages = with pkgs; [
    # Additional network tools beyond router module defaults
    iperf3
    mtr
    lm_sensors
    pciutils
    usbutils
  ];

  # Enable smartd for SSD monitoring
  services.smartd = {
    enable = true;
    autodetect = true;
  };

  # Disable unnecessary services for router
  services.xserver.enable = mkForce false;
  xdg.portal.enable = mkForce false;
  programs.dconf.enable = mkForce false;

  # Performance tuning (additional to router module defaults)
  boot.kernel.sysctl = {
    # Network performance
    "net.core.netdev_max_backlog" = 5000;
    "net.core.rmem_max" = 134217728;
    "net.core.wmem_max" = 134217728;
    "net.ipv4.tcp_rmem" = "4096 87380 67108864";
    "net.ipv4.tcp_wmem" = "4096 65536 67108864";
    "net.ipv4.tcp_congestion_control" = "bbr";

    # Connection tracking
    "net.netfilter.nf_conntrack_max" = 262144;
    "net.netfilter.nf_conntrack_tcp_timeout_established" = 432000;
  };

  # State version
  system.stateVersion = "23.05";
}
