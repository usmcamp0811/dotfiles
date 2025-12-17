{
  lib,
  pkgs,
  inputs,
  ...
}:
with lib;
with lib.campground; {
  imports = [
    ./hardware.nix
    ./disko.nix
    ./impermanence.nix
  ];

  # Locale
  i18n.defaultLocale = "en_US.UTF-8";
  console = {
    font = "Lat2-Terminus16";
    keyMap = "us";
  };

  # Use campground modules for configuration
  campground = {
    cli.aliases.root = enabled;

    suites = {
      common = enabled;
      observability = enabled;
    };

    system = {
      passwds = enabled;
    };

    services = {
      ntp = enabled;
      tang = enabled;

      vault-agent = {
        enable = true;
        settings.vault = {
          address = "https://vault.lan.aicampground.com";
          role-id = "/var/lib/vault/blue-ridge/role-id";
          secret-id = "/var/lib/vault/blue-ridge/secret-id";
        };
      };

      openssh = {
        authorizedKeys = [
          "ecdsa-sha2-nistp521 AAAAE2VjZHNhLXNoYTItbmlzdHA1MjEAAAAIbmlzdHA1MjEAAACFBAGs9njLHA3yyrX6BTf5Z3Xj8jzOh9zVYfJoeai6WhmBtjr34KV0F79YKafvJPS4gasOTFpnKXObvBo0jG3/AIN+dwBohHtFtXSYBgZecFg847XoeN+7cIveqgI2Q1Jn2sFoUTzGiwKxqLRM7ZuTtRJGfoizOxlYHdyovus67jfDxewP5A== mcamp@Butler"
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINLbrIDbLSEpfOc4onBP8y6aKCNEN5rEe0J3h7klfKzG mcamp@butler"
        ];
      };
    };

    ############################################################
    # Router configuration
    ############################################################
    router = {
      enable = true;

      # WAN: upstream network
      wan = {
        interface = "enp1s0";
        dhcp = true;
      };

      # LAN: bridge + gateway
      lan = {
        interfaces = ["enp2s0" "enp3s0" "enp4s0"];
        gateway = "192.169.1.1";
        prefixLength = 24;
      };

      # DHCP for VMs only (static reservations below)
      # Zones will handle DHCP for their respective networks
      dhcp = {
        enable = true;
        rangeStart = "192.169.1.10";
        rangeEnd = "192.169.1.40";
        leaseTime = "12h";
      };

      # DNS forwarding to upstream
      dns = {
        enable = true;
        forwarders = ["1.1.1.1" "1.0.0.1"];
        enableDNSSEC = true;
        dnssecCheckUnsigned = true;
      };

      # Network zones (VLAN-based segmentation)
      zones = {
        enable = true;

        zones = {
          # LAN - Native/untagged VLAN (existing network)
          lan = {
            vlanId = null; # Native VLAN
            subnet = "192.169.1.0/24";
            gateway = "192.169.1.1";
            dhcp = {
              enable = true;
              rangeStart = "192.169.1.50";
              rangeEnd = "192.169.1.200";
            };
            allowInternet = true;
            isolation = "none"; # LAN can talk to all zones
            description = "Main LAN network for trusted devices and VMs";
          };

          # WiFi - VLAN 10
          wifi = {
            vlanId = 10;
            subnet = "192.169.10.0/24";
            gateway = "192.169.10.1";
            dhcp = {
              enable = true;
              rangeStart = "192.169.10.50";
              rangeEnd = "192.169.10.200";
            };
            allowInternet = true;
            isolation = "partial"; # Can access LAN only
            description = "WiFi network for wireless devices";
          };

          # IoT - VLAN 20
          iot = {
            vlanId = 20;
            subnet = "192.169.20.0/24";
            gateway = "192.169.20.1";
            dhcp = {
              enable = true;
              rangeStart = "192.169.20.50";
              rangeEnd = "192.169.20.200";
            };
            allowInternet = true;
            isolation = "full"; # Isolated from other zones
            description = "IoT network for smart home devices";
          };

          # Guest - VLAN 30
          guest = {
            vlanId = 30;
            subnet = "192.169.30.0/24";
            gateway = "192.169.30.1";
            dhcp = {
              enable = true;
              rangeStart = "192.169.30.50";
              rangeEnd = "192.169.30.200";
            };
            allowInternet = true;
            isolation = "full"; # Fully isolated
            description = "Guest network for visitors";
          };
        };

        # Inter-zone routing with granular port/protocol restrictions
        # Uncomment and customize as needed
        interZoneRoutes = [
          # Example: IoT devices can reach Home Assistant on LAN (TCP port 8123 only)
          # {
          #   from = "iot";
          #   to = ["lan"];
          #   protocol = "tcp";
          #   ports = [8123];
          #   destinationIPs = ["192.169.1.100"];  # Home Assistant IP
          #   description = "IoT to Home Assistant";
          # }

          # Example: WiFi can access file shares and SSH on LAN
          # {
          #   from = "wifi";
          #   to = ["lan"];
          #   protocol = "tcp";
          #   ports = [22 139 445];  # SSH, SMB
          #   description = "WiFi to LAN services";
          # }

          # Example: WiFi can ping LAN devices
          # {
          #   from = "wifi";
          #   to = ["lan"];
          #   protocol = "icmp";
          #   description = "WiFi ICMP to LAN";
          # }

          # Example: LAN has full admin access to IoT network
          # {
          #   from = "lan";
          #   to = ["iot"];
          #   description = "LAN admin access to IoT";
          # }

          # Example: IoT can reach DNS/NTP on LAN
          # {
          #   from = "iot";
          #   to = ["lan"];
          #   protocol = "udp";
          #   ports = [53 123];  # DNS, NTP
          #   description = "IoT to LAN DNS/NTP";
          # }

          # Example: Guest can access printer only
          # {
          #   from = "guest";
          #   to = ["lan"];
          #   protocol = "tcp";
          #   ports = [9100 631];  # IPP, HP JetDirect
          #   destinationIPs = ["192.169.1.50"];  # Printer IP
          #   description = "Guest to LAN printer";
          # }
        ];
      };

      # Router security hardening
      security = {
        enable = true;
        enableSSH = true;
        sshPort = 22;
        fail2ban = {
          enable = true;
          maxRetry = 3;
          banTime = 3600;
        };
      };

      # Port forwarding (declarative)
      portForwards = [
        {
          port = 443;
          destination = "192.169.1.20";
          protocol = "tcp";
          description = "HTTPS to pub-traefik";
        }
        {
          port = 80;
          destination = "192.169.1.30";
          destinationPort = 3000;
          protocol = "tcp";
          description = "AdGuard Web UI via port 80 -> 3000 (optional)";
        }
      ];
    };

    # User configuration
    user = {
      name = "admin";
      fullName = "System Administrator";
      email = "admin@aicampground.com";
      extraGroups = [];
      uid = 1000;
    };
  };

  # Static DHCP leases for MicroVMs
  # dnsmasq will ONLY serve these VMs, ignoring all other DHCP requests
  services.dnsmasq.settings = {
    dhcp-host = [
      "02:00:00:00:00:10,192.169.1.10,vault"
      "02:00:00:00:00:11,192.169.1.11,websites"
      "02:00:00:00:00:20,192.169.1.20,pub-traefik"
      "02:00:00:00:00:21,192.169.1.21,lan-traefik"
      "02:00:00:00:00:30,192.169.1.30,adguard"
    ];

    # CRITICAL: Only serve DHCP to VMs with static reservations above
    # This ensures client devices get DHCP from AdGuard (range 50-200)
    dhcp-ignore = "tag:!known";
  };

  ############################################################
  # MicroVM host configuration
  ############################################################
  microvm.host = {
    enable = true;
    useNotifySockets = true;
  };

  microvm.vms = {
    vault = {
      flake = inputs.self;
      autostart = true;
      restartIfChanged = true;
      updateFlake = "git+https://gitlab.com/usmcamp0811/dotfiles.git";
    };
    websites = {
      flake = inputs.self;
      autostart = true;
      restartIfChanged = true;
      updateFlake = "git+https://gitlab.com/usmcamp0811/dotfiles.git";
    };
    pub-traefik = {
      flake = inputs.self;
      autostart = true;
      restartIfChanged = true;
      updateFlake = "git+https://gitlab.com/usmcamp0811/dotfiles.git";
    };
    lan-traefik = {
      flake = inputs.self;
      autostart = true;
      restartIfChanged = true;
      updateFlake = "git+https://gitlab.com/usmcamp0811/dotfiles.git";
    };
    adguard = {
      flake = inputs.self;
      autostart = true;
      restartIfChanged = true;
      updateFlake = "git+https://gitlab.com/usmcamp0811/dotfiles.git";
    };
  };

  ############################################################
  # Networking
  ############################################################
  networking.useNetworkd = true;

  # Router module controls firewall; avoid conflicts.
  networking.firewall.enable = lib.mkForce false;

  # Host itself should use AdGuard for DNS (plus a fallback)
  networking.nameservers = [
    "192.169.1.30"
    "1.1.1.1"
  ];

  # Add MicroVM TAP interfaces to the LAN bridge (br-lan)
  systemd.network.networks."30-lan-vm-taps" = {
    matchConfig.Name = "vm-*";
    networkConfig.Bridge = "br-lan";
    linkConfig.RequiredForOnline = "enslaved";
  };

  system.stateVersion = "23.05";
}
