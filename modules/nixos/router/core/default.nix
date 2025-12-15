{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.campground; let
  cfg = config.campground.router;

  # Generate NAT DNAT rules for port forwards
  mkPortForwardNatRules = portForwards:
    concatMapStrings (pf: let
      destPort = if pf.destinationPort != null then pf.destinationPort else pf.port;
      protocols = if pf.protocol == "both" then ["tcp" "udp"] else [pf.protocol];
      comment = optionalString (pf.description != "") "# ${pf.description}\n      ";
    in
      concatMapStrings (proto: ''
        ${comment}iifname "${cfg.wan.interface}" ${proto} dport ${toString pf.port} dnat to ${pf.destination}:${toString destPort}
      '') protocols
    ) portForwards;

  # Generate firewall forward rules for port forwards
  mkPortForwardFilterRules = portForwards:
    concatMapStrings (pf: let
      destPort = if pf.destinationPort != null then pf.destinationPort else pf.port;
      protocols = if pf.protocol == "both" then ["tcp" "udp"] else [pf.protocol];
      comment = optionalString (pf.description != "") "# ${pf.description}\n        ";
      protoList = if length protocols > 1 then "{${concatStringsSep ", " protocols}}" else head protocols;
    in ''
      ${comment}iifname "${cfg.wan.interface}" oifname "${cfg.lan.bridgeName}" ip daddr ${pf.destination} meta l4proto ${protoList} th dport ${toString destPort} ct state new accept
    ''
    ) portForwards;
in {
  options.campground.router = {
    enable = mkEnableOption "campground router core (WAN+LAN bridge, DHCP, NAT)";

    wan = {
      interface = mkOption {
        type = types.str;
        description = "WAN interface name";
        example = "enp1s0";
      };

      dhcp = mkOption {
        type = types.bool;
        default = true;
        description = "Use DHCP on WAN";
      };

      staticIPv4 = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Static IPv4 CIDR for WAN when dhcp=false (e.g. 203.0.113.10/24)";
      };
    };

    lan = {
      bridgeName = mkOption {
        type = types.str;
        default = "br-lan";
        description = "LAN bridge name";
      };

      interfaces = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Interfaces to enslave into the LAN bridge";
        example = ["enp4s0" "enp3s0"];
      };

      gateway = mkOption {
        type = types.str;
        default = "192.168.1.1";
        description = "Router IPv4 on LAN bridge";
      };

      prefixLength = mkOption {
        type = types.int;
        default = 24;
        description = "LAN prefix length";
      };
    };

    dhcp = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable DHCP server on LAN (dnsmasq)";
      };

      rangeStart = mkOption {
        type = types.str;
        default = "192.168.1.50";
        description = "DHCP pool start";
      };

      rangeEnd = mkOption {
        type = types.str;
        default = "192.168.1.200";
        description = "DHCP pool end";
      };

      leaseTime = mkOption {
        type = types.str;
        default = "12h";
        description = "DHCP lease time";
      };
    };

    dns = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable DNS via dnsmasq on LAN";
      };

      forwarders = mkOption {
        type = types.listOf types.str;
        default = ["1.1.1.1" "1.0.0.1" "8.8.8.8" "8.8.4.4"];
        description = "Upstream DNS servers";
      };
    };

    portForwards = mkOption {
      type = types.listOf (types.submodule {
        options = {
          port = mkOption {
            type = types.port;
            description = "External port to forward from WAN";
            example = 443;
          };

          destination = mkOption {
            type = types.str;
            description = "Internal IP address to forward to";
            example = "192.168.1.100";
          };

          destinationPort = mkOption {
            type = types.nullOr types.port;
            default = null;
            description = "Internal port to forward to (defaults to same as external port)";
            example = 8080;
          };

          protocol = mkOption {
            type = types.enum ["tcp" "udp" "both"];
            default = "tcp";
            description = "Protocol to forward (tcp, udp, or both)";
          };

          description = mkOption {
            type = types.str;
            default = "";
            description = "Description of this port forward";
            example = "HTTPS to web server";
          };
        };
      });
      default = [];
      description = "Declarative port forwarding rules";
      example = literalExpression ''
        [
          {
            port = 443;
            destination = "192.168.1.100";
            protocol = "tcp";
            description = "HTTPS to web server";
          }
          {
            port = 25565;
            destination = "192.168.1.50";
            destinationPort = 25565;
            protocol = "both";
            description = "Minecraft server";
          }
        ]
      '';
    };

    firewall = {
      allowPing = mkOption {
        type = types.bool;
        default = false;
        description = "Allow ICMP ping from WAN";
      };

      extraRules = mkOption {
        type = types.lines;
        default = "";
        description = "Extra nftables rules to append to the ruleset (for advanced use cases)";
        example = ''
          table inet filter {
            chain input {
              tcp dport 8080 accept
            }
          }
        '';
      };
    };
  };

  config = mkIf cfg.enable {
    ############################################################
    # Port forwarding rule generation
    ############################################################
    assertions = map (pf: {
      assertion = pf.destinationPort == null || pf.destinationPort > 0;
      message = "Port forward destination port must be > 0";
    }) cfg.portForwards;

    ############################################################
    # Forwarding (router behavior)
    ############################################################
    boot.kernel.sysctl = {
      "net.ipv4.conf.all.forwarding" = 1;
      "net.ipv4.ip_forward" = 1;
    };

    ############################################################
    # systemd-networkd: WAN + LAN bridge
    ############################################################
    systemd.network.enable = true;

    systemd.network.netdevs."10-${cfg.lan.bridgeName}" = {
      netdevConfig = {
        Kind = "bridge";
        Name = cfg.lan.bridgeName;
      };
    };

    systemd.network.networks =
      {
        # WAN
        "20-wan" = {
          matchConfig.Name = cfg.wan.interface;
          networkConfig = {
            DHCP = mkIf cfg.wan.dhcp "ipv4";
          };
          address = mkIf (!cfg.wan.dhcp && cfg.wan.staticIPv4 != null) [cfg.wan.staticIPv4];
          linkConfig.RequiredForOnline = "routable";
        };

        # LAN bridge
        "30-lan-bridge" = {
          matchConfig.Name = cfg.lan.bridgeName;
          networkConfig = {
            Address = "${cfg.lan.gateway}/${toString cfg.lan.prefixLength}";
          };
          linkConfig.RequiredForOnline = "no";
        };
      }
      // (listToAttrs (map (
          iface:
            nameValuePair "31-lan-${iface}" {
              matchConfig.Name = iface;
              networkConfig.Bridge = cfg.lan.bridgeName;
              linkConfig.RequiredForOnline = "enslaved";
            }
        )
        cfg.lan.interfaces));

    ############################################################
    # DHCP + DNS (dnsmasq) on LAN
    ############################################################
    services.dnsmasq = mkIf (cfg.dhcp.enable || cfg.dns.enable) {
      enable = true;
      settings =
        {
          interface = cfg.lan.bridgeName;
          bind-interfaces = true;
        }
        // (lib.optionalAttrs cfg.dhcp.enable {
          # DHCP (Butler needs this)
          dhcp-range = [
            "${cfg.dhcp.rangeStart},${cfg.dhcp.rangeEnd},${cfg.dhcp.leaseTime}"
          ];

          dhcp-option = [
            "option:router,${cfg.lan.gateway}"
            "option:dns-server,${cfg.lan.gateway}"
          ];
        })
        // (lib.optionalAttrs cfg.dns.enable {
          no-resolv = true;
          server = cfg.dns.forwarders;
        });
    };

    ############################################################
    # Firewall + NAT (nftables)
    ############################################################
    networking.firewall.enable = false;
    networking.nftables.enable = true;

    networking.nftables.ruleset = ''
      table inet filter {
        chain input {
          type filter hook input priority 0; policy drop;

          ct state { established, related } accept
          iifname "lo" accept

          # LAN can talk to router
          iifname "${cfg.lan.bridgeName}" accept

          # DHCP + DNS (router services)
          udp dport {67, 68} accept
          tcp dport 53 accept
          udp dport 53 accept

          ${optionalString cfg.firewall.allowPing ''
          # Allow ICMP ping from WAN
          ip protocol icmp icmp type echo-request accept
          ''}
        }

        chain forward {
          type filter hook forward priority 0; policy drop;

          ct state { established, related } accept

          # LAN -> WAN allowed
          iifname "${cfg.lan.bridgeName}" oifname "${cfg.wan.interface}" accept

          ${optionalString (cfg.portForwards != []) ''
          # Port forwarding rules
          ${mkPortForwardFilterRules cfg.portForwards}''}
        }
      }

      table ip nat {
        chain prerouting {
          type nat hook prerouting priority -100;
          ${optionalString (cfg.portForwards != []) ''
          # Port forwarding DNAT rules
          ${mkPortForwardNatRules cfg.portForwards}''}
        }

        chain postrouting {
          type nat hook postrouting priority 100;
          oifname "${cfg.wan.interface}" masquerade
        }
      }

      ${cfg.firewall.extraRules}
    '';
  };
}
