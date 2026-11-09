{
  lib,
  pkgs,
  config,
  ...
}:
with lib;
with lib.fmf; {
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

    # Shares and the writable store overlay come from ./storage.nix (fmf.host), not from here.

    vcpu = 2;
    mem = 2047;
    socket = "control.socket";

    volumes = [
      {
        image = "/persist/vm-data/vm-adguard/adguard-data.img";
        mountPoint = "/var/lib/AdGuardHome";
        size = 5120;
      }
    ];
  };

  ############################################################
  # Networking: the NIC name (lan0, which AdGuard's DHCP interface_name relies on), address, gateway, DNS and
  # tap come from ./host.nix (fmf.host.network.derive). Static IP: this VM is the DHCP server.
  ############################################################
  services.resolved.enable = false;

  # Avoid DHCP being blocked by guest firewall
  networking.firewall.enable = false;

  nix.optimise.automatic = lib.mkForce false;
  nix.settings.auto-optimise-store = lib.mkForce false;

  ############################################################
  # Base system configuration
  ############################################################
  fmf = {
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
          role-id = "/var/lib/vault/vm-adguard/role-id";
          secret-id = "/var/lib/vault/vm-adguard/secret-id";
        };
      };

      openssh = {
        enable = true;
        authorizedKeys = [
          "ecdsa-sha2-nistp521 AAAAE2VjZHNhLXNoYTItbmlzdHA1MjEAAAAIbmlzdHA1MjEAAACFBAGs9njLHA3yyrX6BTf5Z3Xj8jzOh9zVYfJoeai6WhmBtjr34KV0F79YKafvJPS4gasOTFpnKXObvBo0jG3/AIN+dwBohHtFtXSYBgZecFg847XoeN+7cIveqgI2Q1Jn2sFoUTzGiwKxqLRM7ZuTtRJGfoizOxlYHdyovus67jfDxewP5A== mcamp@Butler"
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINLbrIDbLSEpfOc4onBP8y6aKCNEN5rEe0J3h7klfKzG mcamp@butler"
        ];
      };

      ############################################################
      # AdGuard Home DNS + DHCP
      #
      # NOTE: AdGuard *does* care about interface_name for DHCP.
      # Binding to lan0 avoids all the eth0/ens3 naming flakiness.
      ############################################################
      adguard = {
        enable = true;
        mutableSettings = false;
        host = "0.0.0.0";
        port = 3000;

        dns = {
          bindHosts = ["0.0.0.0"];
          port = 53;
          # Encrypted DNS using DoH (DNS over HTTPS) for privacy from ISP
          upstreamDns = [
            "https://cloudflare-dns.com/dns-query" # Cloudflare DoH (primary)
            "https://dns.google/dns-query" # Google DoH (backup)
            "https://dns.quad9.net/dns-query" # Quad9 DoH (backup)
          ];
          # Bootstrap DNS for resolving DoH server hostnames (unencrypted, but only for initial connection)
          bootstrapDns = [
            "1.1.1.1"
            "8.8.8.8"
          ];
          enableDNSSEC = true;
        };

        filtering.filters = [
          {
            enabled = true;
            url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_1.txt";
            name = "AdGuard DNS filter";
          }
          {
            enabled = true;
            url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_2.txt";
            name = "AdAway Default Blocklist";
          }
          {
            enabled = true;
            url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_4.txt";
            name = "Dan Pollock's List";
          }
          {
            enabled = true;
            url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_24.txt";
            name = "WindowsSpyBlocker - Hosts spy rules";
          }
          {
            enabled = true;
            url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_38.txt";
            name = "The Big List of Hacked Malware Web Sites";
          }
          {
            enabled = true;
            url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_6.txt";
            name = "NoCoin Filter List";
          }
          {
            enabled = true;
            url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_7.txt";
            name = "Perflyst and Dandelion Sprout's Smart-TV Blocklist";
          }
          {
            enabled = true;
            url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_30.txt";
            name = "Phishing URL Blocklist";
          }
          {
            enabled = true;
            url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_11.txt";
            name = "Malicious URL Blocklist";
          }
          {
            enabled = true;
            url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_9.txt";
            name = "The Block List Project - Malware List";
          }
          {
            enabled = true;
            url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_10.txt";
            name = "Dandelion Sprout's Anti-Malware List";
          }
          {
            enabled = true;
            url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_8.txt";
            name = "Online Malicious URL Blocklist";
          }
          {
            enabled = true;
            url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_12.txt";
            name = "Scam Blocklist by DurableNapkin";
          }
          {
            enabled = true;
            url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_31.txt";
            name = "Stalkerware Indicators List";
          }
          {
            enabled = true;
            url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_59.txt";
            name = "1Hosts (Lite)";
          }
          {
            enabled = true;
            url = "https://raw.githubusercontent.com/ph00lt0/blocklist/master/blocklist.txt";
            name = "ph00lt0's blocklist";
          }
          {
            enabled = true;
            url = "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/domains/native.amazon.txt";
            name = "HaGeZi - Amazon Native Ads (Domains)";
          }
          {
            enabled = true;
            url = "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/native.amazon.txt";
            name = "HaGeZi - Amazon Native Ads (AdBlock)";
          }
        ];

        # DHCP enabled for LAN only (192.169.1.x)
        # Blue Ridge dnsmasq handles DHCP for WiFi/IoT/Guest zones
        # All zones use AdGuard for DNS filtering
        # this doesnt work like i want
        # dhcp = {
        #   enable = true;
        #   interface = "lan0";
        #   gatewayIp = "192.169.1.1";
        #   subnetMask = "255.255.255.0";
        #   rangeStart = "192.169.1.50";
        #   rangeEnd = "192.169.1.200";
        #   leaseDuration = 43200; # 12 hours
        #
        #   # Static DHCP leases (MAC → IP)
        #   staticLeases = [
        #     {
        #       mac = "60:6d:3c:c2:4a:6e";
        #       ip = "192.169.1.100";
        #       hostname = "butler";
        #     }
        #   ];
        # };
      };
    };
  };

  # Override systemd service to use static user instead of DynamicUser
  # This is necessary because /var/lib/AdGuardHome is on a persistent volume
  systemd.services.adguardhome.serviceConfig = {
    DynamicUser = lib.mkForce false;
    User = "adguardhome";
    Group = "adguardhome";
    StateDirectory = lib.mkForce "AdGuardHome";
  };

  system.stateVersion = "23.05";
}
