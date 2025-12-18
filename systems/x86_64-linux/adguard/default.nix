{
  lib,
  pkgs,
  config,
  ...
}:
with lib;
with lib.campground; {
  # Set snowfallorg user name for home-manager
  home-manager.users.admin.snowfallorg.user.name = "admin";

  # MicroVMs don't use bootloaders - booted directly by QEMU
  boot.loader.grub.enable = lib.mkForce false;
  boot.loader.systemd-boot.enable = lib.mkForce false;

  ############################################################
  # MicroVM configuration
  ############################################################
  microvm = {
    hypervisor = "qemu";

    shares = [
      {
        proto = "virtiofs";
        tag = "ro-store";
        source = "/nix/store";
        mountPoint = "/nix/store";
      }
      {
        proto = "virtiofs";
        tag = "rw-store";
        source = "/persist/vm-stores/adguard/nix-store";
        mountPoint = "/nix/.rw-store";
      }
      {
        proto = "virtiofs";
        tag = "vault-agent";
        source = "/persist/system/var/lib/vault/adguard";
        mountPoint = "/var/lib/vault/adguard";
      }
    ];

    interfaces = [
      {
        type = "tap";
        id = "vm-adguard";
        mac = "02:00:00:00:00:30";
      }
    ];

    vcpu = 2;
    mem = 2047;
    socket = "control.socket";

    volumes = [
      {
        image = "/persist/vm-data/adguard/adguard-data.img";
        mountPoint = "/var/lib/AdGuardHome";
        size = 5120;
      }
    ];
  };

  ############################################################
  # Deterministic NIC name (critical for AdGuard DHCP)
  ############################################################
  systemd.network.links."10-lan0" = {
    matchConfig.MACAddress = "02:00:00:00:00:30";
    linkConfig.Name = "lan0";
  };

  # Explicit network configuration for lan0
  systemd.network.networks."20-lan0" = {
    matchConfig.Name = "lan0";
    address = ["192.169.1.30/24"];
    gateway = ["192.169.1.1"];
    networkConfig = {
      DHCP = "no";
      IPv6AcceptRA = false;
    };
    linkConfig.RequiredForOnline = "routable";
  };

  ############################################################
  # Networking - static IP (this VM is DHCP server)
  ############################################################
  networking.useNetworkd = true;
  networking.useDHCP = false;
  services.resolved.enable = false;

  # Avoid DHCP being blocked by guest firewall
  networking.firewall.enable = false;

  networking.defaultGateway = {
    address = "192.169.1.1";
    interface = "lan0";
  };

  networking.nameservers = [
    "1.1.1.1"
    "1.0.0.1"
    "8.8.8.8"
    "8.8.4.4"
  ];

  nix.optimise.automatic = lib.mkForce false;
  nix.settings.auto-optimise-store = lib.mkForce false;

  ############################################################
  # Base system configuration
  ############################################################
  campground = {
    suites.common = enabled;

    user = {
      name = "admin";
      fullName = "AdGuard Administrator";
      email = "admin@aicampground.com";
      extraGroups = ["wheel"];
      uid = 1000;
    };

    services = {
      vault-agent = {
        enable = true;
        settings.vault = {
          address = "https://vault.lan.aicampground.com";
          role-id = "/var/lib/vault/adguard/role-id";
          secret-id = "/var/lib/vault/adguard/secret-id";
        };
      };

      openssh = {
        enable = true;
        authorizedKeys = [
          "ecdsa-sha2-nistp521 AAAAE2VjZHNhLXNoYTItbmlzdHA1MjEAAAAIbmlzdHA1MjEAAACFBAGs9njLHA3yyrX6BTf5Z3Xj8jzOh9zVYfJoeai6WhmBtjr34KV0F79YKafvJPS4gasOTFpnKXObvBo0jG3/AIN+dwBohHtFtXSYBgZecFg847XoeN+7cIveqgI2Q1Jn2sFoUTzGiwKxqLRM7ZuTtRJGfoizOxlYHdyovus67jfDxewP5A== mcamp@Butler"
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINLbrIDbLSEpfOc4onBP8y6aKCNEN5rEe0J3h7klfKzG mcamp@butler"
        ];
      };
    };
  };

  ############################################################
  # AdGuard Home DNS + DHCP
  #
  # NOTE: AdGuard *does* care about interface_name for DHCP.
  # Binding to lan0 avoids all the eth0/ens3 naming flakiness.
  ############################################################
  services.adguardhome = {
    enable = true;
    # mutableSettings = true;
    host = "0.0.0.0";
    port = 3000;

    settings = {
      dns = {
        bind_hosts = ["0.0.0.0"];
        port = 53;
        upstream_dns = [
          "1.1.1.1"
          "1.0.0.1"
          "8.8.8.8"
          "8.8.4.4"
        ];
      };

      filters = [
        {
          enabled = true;
          url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_1.txt";
          name = "AdGuard DNS filter";
          id = 1;
        }
        {
          enabled = true;
          url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_2.txt";
          name = "AdAway Default Blocklist";
          id = 2;
        }
        {
          enabled = true;
          url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_4.txt";
          name = "Dan Pollock's List";
          id = 4;
        }
        {
          enabled = true;
          url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_24.txt";
          name = "WindowsSpyBlocker - Hosts spy rules";
          id = 24;
        }
        {
          enabled = true;
          url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_38.txt";
          name = "The Big List of Hacked Malware Web Sites";
          id = 38;
        }
        {
          enabled = true;
          url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_6.txt";
          name = "NoCoin Filter List";
          id = 6;
        }
        {
          enabled = true;
          url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_7.txt";
          name = "Perflyst and Dandelion Sprout's Smart-TV Blocklist";
          id = 7;
        }
        {
          enabled = true;
          url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_30.txt";
          name = "Phishing URL Blocklist";
          id = 30;
        }
        {
          enabled = true;
          url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_11.txt";
          name = "Malicious URL Blocklist";
          id = 11;
        }
        {
          enabled = true;
          url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_9.txt";
          name = "The Block List Project - Malware List";
          id = 9;
        }
        {
          enabled = true;
          url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_10.txt";
          name = "Dandelion Sprout's Anti-Malware List";
          id = 10;
        }
        {
          enabled = true;
          url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_8.txt";
          name = "Online Malicious URL Blocklist";
          id = 8;
        }
        {
          enabled = true;
          url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_12.txt";
          name = "Scam Blocklist by DurableNapkin";
          id = 12;
        }
        {
          enabled = true;
          url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_31.txt";
          name = "Stalkerware Indicators List";
          id = 31;
        }
        {
          enabled = true;
          url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_59.txt";
          name = "1Hosts (Lite)";
          id = 59;
        }
        {
          enabled = true;
          url = "https://raw.githubusercontent.com/ph00lt0/blocklist/master/blocklist.txt";
          name = "ph00lt0's blocklist";
          id = 100;
        }
        {
          enabled = true;
          url = "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/domains/native.amazon.txt";
          name = "HaGeZi - Amazon Native Ads (Domains)";
          id = 101;
        }
        {
          enabled = true;
          url = "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/native.amazon.txt";
          name = "HaGeZi - Amazon Native Ads (AdBlock)";
          id = 102;
        }
      ];
      # DHCP enabled for LAN only (192.169.1.x)
      # Blue Ridge dnsmasq handles DHCP for WiFi/IoT/Guest zones
      # All zones use AdGuard for DNS filtering
      dhcp = {
        enabled = true;
        interface_name = "lan0";

        dhcpv4 = {
          gateway_ip = "192.169.1.1";
          subnet_mask = "255.255.255.0";
          range_start = "192.169.1.50";
          range_end = "192.169.1.200";
          lease_duration = 43200; # 12 hours
        };

        # Static DHCP leases (MAC → IP)
        static_leases = [
          {
            mac = "60:6d:3c:c2:4a:6e";
            ip = "192.169.1.100";
            hostname = "butler";
          }
        ];
      };
    };
  };

  # Persistent volume-safe service config
  systemd.services.adguardhome.serviceConfig = {
    DynamicUser = lib.mkForce false;
    User = "adguardhome";
    Group = "adguardhome";
    StateDirectory = lib.mkForce "AdGuardHome";
  };

  users.users.adguardhome = {
    isSystemUser = true;
    group = "adguardhome";
    home = "/var/lib/AdGuardHome";
  };
  users.groups.adguardhome = {};

  system.stateVersion = "23.05";
}
