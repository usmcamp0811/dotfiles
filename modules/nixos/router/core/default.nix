# Router base configuration module
{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:
with lib;
with lib.campground; let
  cfg = config.campground.router;
in {
  options.campground.router = {
    enable = mkEnableOption "Router configuration";

    wan = {
      interface = mkOption {
        type = types.str;
        description = "WAN interface name";
        example = "enp1s0";
      };

      dhcp = mkOption {
        type = types.bool;
        default = true;
        description = "Use DHCP on WAN interface";
      };

      staticIP = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Static IP for WAN interface (if not using DHCP)";
        example = "203.0.113.10/24";
      };
    };

    lan = {
      interfaces = mkOption {
        type = types.listOf types.str;
        description = "LAN interfaces to bridge together";
        example = ["enp2s0" "enp3s0" "enp4s0"];
      };

      subnet = mkOption {
        type = types.str;
        description = "LAN subnet";
        example = "192.168.1.0/24";
      };

      gateway = mkOption {
        type = types.str;
        description = "Router IP address on LAN";
        example = "192.168.1.1";
      };
    };

    enableIPv6 = mkOption {
      type = types.bool;
      default = false;
      description = "Enable IPv6 routing and RA";
    };

    dns = {
      forwarders = mkOption {
        type = types.listOf types.str;
        default = ["1.1.1.1" "1.0.0.1" "8.8.8.8" "8.8.4.4"];
        description = "DNS forwarders";
      };

      enableDNSSEC = mkOption {
        type = types.bool;
        default = true;
        description = "Enable DNSSEC validation";
      };
    };

    firewall = {
      allowPing = mkOption {
        type = types.bool;
        default = false;
        description = "Allow ping on WAN interface";
      };

      extraRules = mkOption {
        type = types.lines;
        default = "";
        description = "Extra nftables rules";
      };
    };
  };

  config = mkIf cfg.enable {
    # Enable IP forwarding
    boot.kernel.sysctl = {
      "net.ipv4.conf.all.forwarding" = 1;
      "net.ipv6.conf.all.forwarding" = mkIf cfg.enableIPv6 1;

      # Security hardening
      "net.ipv4.conf.all.rp_filter" = 1;
      "net.ipv4.conf.default.rp_filter" = 1;
      "net.ipv4.conf.all.accept_redirects" = 0;
      "net.ipv4.conf.default.accept_redirects" = 0;
      "net.ipv4.conf.all.send_redirects" = 0;
      "net.ipv4.conf.default.send_redirects" = 0;
      "net.ipv4.conf.all.accept_source_route" = 0;
      "net.ipv4.conf.default.accept_source_route" = 0;
      "net.ipv4.tcp_syncookies" = 1;
      "net.ipv4.icmp_echo_ignore_broadcasts" = 1;
      "net.ipv4.icmp_ignore_bogus_error_responses" = 1;

      # Network performance tuning
      "net.core.netdev_max_backlog" = 5000;
      "net.core.rmem_max" = 134217728;
      "net.core.wmem_max" = 134217728;
      "net.ipv4.tcp_rmem" = "4096 87380 67108864";
      "net.ipv4.tcp_wmem" = "4096 65536 67108864";
      "net.ipv4.tcp_congestion_control" = "bbr";

      # Connection tracking for router workloads
      "net.netfilter.nf_conntrack_max" = 262144;
      "net.netfilter.nf_conntrack_tcp_timeout_established" = 432000;
    };

    # Create bridge for LAN interfaces
    systemd.network = {
      enable = true;

      # LAN bridge
      netdevs."10-lan" = {
        netdevConfig = {
          Kind = "bridge";
          Name = "br-lan";
        };
      };

      networks =
        {
          # WAN interface
          "20-wan" = {
            matchConfig.Name = cfg.wan.interface;
            networkConfig = {
              DHCP = mkIf cfg.wan.dhcp "ipv4";
              IPv6AcceptRA = mkIf cfg.enableIPv6 true;
            };
            address = mkIf (!cfg.wan.dhcp && cfg.wan.staticIP != null) [cfg.wan.staticIP];
            linkConfig.RequiredForOnline = "routable";
          };

          # LAN bridge
          "30-lan-bridge" = {
            matchConfig.Name = "br-lan";
            networkConfig = {
              Address = "${cfg.lan.gateway}/${
                last (splitString "/" cfg.lan.subnet)
              }";
              DHCPServer = false; # Using Kea instead
              IPv6SendRA = mkIf cfg.enableIPv6 true;
            };
            linkConfig.RequiredForOnline = "no";
          };
        }
        // (listToAttrs (
          map (iface:
            nameValuePair "30-lan-${iface}" {
              matchConfig.Name = iface;
              networkConfig.Bridge = "br-lan";
              linkConfig.RequiredForOnline = "enslaved";
            })
          cfg.lan.interfaces
        ));
    };

    # Basic firewall with nftables
    networking.nftables = {
      enable = true;
      ruleset = ''
        table inet filter {
          chain input {
            type filter hook input priority 0; policy drop;

            # Allow established/related connections
            ct state {established, related} accept

            # Allow loopback
            iifname "lo" accept

            # Allow LAN to router
            iifname "br-lan" accept

            # Allow ping if enabled
            ${optionalString cfg.firewall.allowPing ''
          ip protocol icmp icmp type echo-request accept
          ip6 nexthdr icmpv6 icmpv6 type echo-request accept
        ''}

            # Drop invalid packets
            ct state invalid drop
          }

          chain forward {
            type filter hook forward priority 0; policy drop;

            # Allow established/related connections
            ct state {established, related} accept

            # Allow LAN to WAN
            iifname "br-lan" oifname "${cfg.wan.interface}" accept

            # Drop invalid packets
            ct state invalid drop
          }

          chain output {
            type filter hook output priority 0; policy accept;
          }
        }

        table inet nat {
          chain prerouting {
            type nat hook prerouting priority -100;
          }

          chain postrouting {
            type nat hook postrouting priority 100;

            # Masquerade LAN to WAN
            oifname "${cfg.wan.interface}" masquerade
          }
        }

        ${cfg.firewall.extraRules}
      '';
    };

    # DNS resolver
    services.unbound = {
      enable = true;
      settings = {
        server = {
          interface = ["127.0.0.1" "::1" cfg.lan.gateway];
          access-control = [
            "127.0.0.0/8 allow"
            "::1 allow"
            "${cfg.lan.subnet} allow"
          ];

          # Security
          hide-identity = true;
          hide-version = true;
          harden-glue = true;
          harden-dnssec-stripped = true;
          use-caps-for-id = true;

          # DNSSEC
          auto-trust-anchor-file = mkIf cfg.dns.enableDNSSEC "/var/lib/unbound/root.key";

          # Performance
          num-threads = 2;
          msg-cache-slabs = 4;
          rrset-cache-slabs = 4;
          infra-cache-slabs = 4;
          key-cache-slabs = 4;
        };

        forward-zone = [
          {
            name = ".";
            forward-addr = cfg.dns.forwarders;
          }
        ];
      };
    };

    # Open DNS port on LAN
    networking.firewall.interfaces."br-lan" = {
      allowedTCPPorts = [53];
      allowedUDPPorts = [53];
    };
  };
}
