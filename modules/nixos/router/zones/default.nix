# Router network zones module
# Provides VLAN-based network segmentation with zone-based firewall
{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.campground; let
  cfg = config.campground.router.zones;
  routerCfg = config.campground.router;

  # Generate nftables sets for each zone
  mkZoneSet = zoneName: zone: ''
    set ${zoneName}_nets {
      type ipv4_addr
      flags interval
      elements = { ${zone.subnet} }
    }
  '';

  # Generate inter-zone forwarding rules
  mkInterZoneRules = concatMapStrings (rule: let
    fromZone = cfg.zones.${rule.from};

    # Build protocol matcher
    protoMatch = if rule.protocol == null || rule.protocol == "all"
      then ""
      else if rule.protocol == "icmp"
      then "ip protocol icmp "
      else "meta l4proto ${rule.protocol} ";

    # Build port matcher
    portMatch =
      if rule.ports != null && rule.ports != []
      then
        if length rule.ports == 1
        then "th dport ${toString (head rule.ports)} "
        else "th dport { ${concatMapStringsSep ", " toString rule.ports} } "
      else if rule.portRanges != null && rule.portRanges != []
      then concatMapStrings (range: "th dport ${toString range.start}-${toString range.end} ") rule.portRanges
      else "";

    # Generate rules for each destination zone
    mkDestRule = to: let
      toZone = cfg.zones.${to};

      # Build destination IP matcher
      destMatch =
        if rule.destinationIPs != null && rule.destinationIPs != []
        then
          if length rule.destinationIPs == 1
          then "ip daddr ${head rule.destinationIPs} "
          else "ip daddr { ${concatStringsSep ", " rule.destinationIPs} } "
        else "";

      comment = optionalString (rule.description != "") "# ${rule.description}\n        ";
    in ''
      ${comment}iifname "${fromZone.interface}" oifname "${toZone.interface}" ${destMatch}${protoMatch}${portMatch}accept
    '';
  in
    concatMapStrings mkDestRule rule.to
  ) cfg.interZoneRoutes;

  # Generate zone to WAN rules
  mkZoneToWanRules = concatMapStrings (zoneName: let
    zone = cfg.zones.${zoneName};
  in
    optionalString zone.allowInternet ''
      # ${zoneName} -> WAN
      iifname "${zone.interface}" oifname "${routerCfg.wan.interface}" accept
    '')
    (attrNames cfg.zones);

  # Generate DHCP configuration for a zone
  mkZoneDHCP = zoneName: zone:
    optionalAttrs zone.dhcp.enable {
      dhcp-range = [
        "${zone.interface},${zone.dhcp.rangeStart},${zone.dhcp.rangeEnd},${zone.dhcp.leaseTime}"
      ];
    };

  # All zone DHCP configs merged
  allZoneDHCP = let
    allRanges = concatMap (zoneName: let
      zone = cfg.zones.${zoneName};
    in
      optional zone.dhcp.enable
        "${zone.interface},${zone.dhcp.rangeStart},${zone.dhcp.rangeEnd},${zone.dhcp.leaseTime}"
    ) (attrNames cfg.zones);
  in
    optionalAttrs (allRanges != []) {
      dhcp-range = allRanges;
    };
in {
  options.campground.router.zones = {
    enable = mkEnableOption "Network zones with VLAN segmentation" // {default = routerCfg.enable;};

    zones = mkOption {
      type = types.attrsOf (types.submodule ({name, ...}: {
        options = {
          vlanId = mkOption {
            type = types.nullOr types.int;
            default = null;
            description = "VLAN ID (null for untagged/native VLAN)";
            example = 10;
          };

          subnet = mkOption {
            type = types.str;
            description = "Network subnet in CIDR notation";
            example = "192.168.10.0/24";
          };

          gateway = mkOption {
            type = types.str;
            description = "Gateway IP address for this zone";
            example = "192.168.10.1";
          };

          interface = mkOption {
            type = types.str;
            default =
              if name == "lan"
              then routerCfg.lan.bridgeName
              else "${routerCfg.lan.bridgeName}.${toString (if cfg.zones.${name}.vlanId != null then cfg.zones.${name}.vlanId else 0)}";
            description = "Interface name for this zone";
            readOnly = true;
          };

          dhcp = {
            enable = mkOption {
              type = types.bool;
              default = true;
              description = "Enable DHCP server for this zone";
            };

            rangeStart = mkOption {
              type = types.str;
              description = "DHCP pool start address";
              example = "192.168.10.50";
            };

            rangeEnd = mkOption {
              type = types.str;
              description = "DHCP pool end address";
              example = "192.168.10.200";
            };

            leaseTime = mkOption {
              type = types.str;
              default = "12h";
              description = "DHCP lease time";
            };

            staticLeases = mkOption {
              type = types.listOf (types.submodule {
                options = {
                  mac = mkOption {
                    type = types.str;
                    description = "MAC address";
                    example = "aa:bb:cc:dd:ee:ff";
                  };

                  ip = mkOption {
                    type = types.str;
                    description = "Static IP address to assign";
                    example = "192.168.10.100";
                  };

                  hostname = mkOption {
                    type = types.nullOr types.str;
                    default = null;
                    description = "Hostname for this device (optional)";
                    example = "my-printer";
                  };
                };
              });
              default = [];
              description = "Static DHCP leases (MAC → IP mappings)";
              example = literalExpression ''
                [
                  {
                    mac = "aa:bb:cc:dd:ee:ff";
                    ip = "192.168.10.100";
                    hostname = "printer";
                  }
                  {
                    mac = "11:22:33:44:55:66";
                    ip = "192.168.10.101";
                    hostname = "smart-tv";
                  }
                ]
              '';
            };
          };

          dns = {
            enable = mkOption {
              type = types.bool;
              default = true;
              description = "Enable DNS for this zone";
            };

            servers = mkOption {
              type = types.nullOr (types.listOf types.str);
              default = null;
              description = ''
                DNS servers to advertise to DHCP clients in this zone (via DHCP option 6).
                Null uses the zone gateway (router itself).
                Set to AdGuard IP (e.g., ["192.169.1.30"]) for DNS filtering.
              '';
              example = ["192.169.1.30"];
            };

            customForwarders = mkOption {
              type = types.nullOr (types.listOf types.str);
              default = null;
              description = "Custom DNS forwarders for dnsmasq on this zone (null uses global)";
              example = ["1.1.1.1" "1.0.0.1"];
            };
          };

          allowInternet = mkOption {
            type = types.bool;
            default = true;
            description = "Allow this zone to access the internet (WAN)";
          };

          isolation = mkOption {
            type = types.enum ["full" "partial" "none"];
            default = "full";
            description = ''
              Isolation level:
              - full: No communication with other zones (except via interZoneRoutes)
              - partial: Can communicate with LAN zone only
              - none: Can communicate with all zones
            '';
          };

          description = mkOption {
            type = types.str;
            default = "";
            description = "Human-readable description of this zone";
          };
        };
      }));
      default = {};
      description = "Network zones configuration";
      example = literalExpression ''
        {
          lan = {
            vlanId = null;  # Native/untagged
            subnet = "192.169.1.0/24";
            gateway = "192.169.1.1";
            dhcp = {
              enable = true;
              rangeStart = "192.169.1.50";
              rangeEnd = "192.169.1.200";
            };
            allowInternet = true;
            isolation = "none";
          };
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
            isolation = "partial";
          };
        }
      '';
    };

    interZoneRoutes = mkOption {
      type = types.listOf (types.submodule {
        options = {
          from = mkOption {
            type = types.str;
            description = "Source zone name";
            example = "iot";
          };

          to = mkOption {
            type = types.listOf types.str;
            description = "Destination zone names (list)";
            example = ["lan" "wifi"];
          };

          protocol = mkOption {
            type = types.nullOr (types.enum ["tcp" "udp" "icmp" "all"]);
            default = null;
            description = "Protocol to allow (null = all protocols)";
            example = "tcp";
          };

          ports = mkOption {
            type = types.nullOr (types.listOf types.port);
            default = null;
            description = "Destination ports to allow (null = all ports). Requires protocol to be set.";
            example = [80 443 8123];
          };

          portRanges = mkOption {
            type = types.nullOr (types.listOf (types.submodule {
              options = {
                start = mkOption {
                  type = types.port;
                  description = "Start of port range";
                };
                end = mkOption {
                  type = types.port;
                  description = "End of port range";
                };
              };
            }));
            default = null;
            description = "Port ranges to allow. Requires protocol to be set.";
            example = [{start = 8000; end = 8999;}];
          };

          destinationIPs = mkOption {
            type = types.nullOr (types.listOf types.str);
            default = null;
            description = "Specific destination IPs within the zone (null = entire zone subnet)";
            example = ["192.169.1.100" "192.169.1.101"];
          };

          description = mkOption {
            type = types.str;
            default = "";
            description = "Description of this routing rule";
          };
        };
      });
      default = [];
      description = "Inter-zone routing rules (allows traffic between zones)";
      example = literalExpression ''
        [
          # Allow IoT to reach Home Assistant only
          {
            from = "iot";
            to = ["lan"];
            protocol = "tcp";
            ports = [8123];
            destinationIPs = ["192.169.1.100"];
            description = "IoT to Home Assistant";
          }
          # Allow WiFi to access SMB and SSH on LAN
          {
            from = "wifi";
            to = ["lan"];
            protocol = "tcp";
            ports = [22 139 445];
            description = "WiFi to LAN file sharing and SSH";
          }
          # Allow all traffic from LAN to IoT (admin access)
          {
            from = "lan";
            to = ["iot"];
            description = "LAN admin access to IoT";
          }
        ]
      '';
    };

    extraFirewallRules = mkOption {
      type = types.lines;
      default = "";
      description = "Additional nftables rules for zone-based firewall";
    };
  };

  config = mkIf (routerCfg.enable && cfg.enable) {
    assertions = [
      {
        assertion = cfg.zones ? lan;
        message = "router.zones must define a 'lan' zone";
      }
      {
        assertion = (cfg.zones.lan.vlanId or null) == null;
        message = "lan zone must not have a VLAN ID (it's the native VLAN)";
      }
    ]
    ++ (map (rule: {
      assertion = (rule.ports == null && rule.portRanges == null) ||
                  (rule.protocol != null && rule.protocol != "icmp");
      message = "interZoneRoute from '${rule.from}': ports/portRanges require protocol to be 'tcp', 'udp', or 'all'";
    }) cfg.interZoneRoutes)
    ++ (map (rule: {
      assertion = all (zoneName: cfg.zones ? ${zoneName}) rule.to;
      message = "interZoneRoute from '${rule.from}': destination zone(s) must exist in router.zones";
    }) cfg.interZoneRoutes)
    ++ (map (rule: {
      assertion = cfg.zones ? ${rule.from};
      message = "interZoneRoute: source zone '${rule.from}' does not exist in router.zones";
    }) cfg.interZoneRoutes);

    ############################################################
    # VLAN interfaces via systemd-networkd
    ############################################################
    systemd.network.netdevs = mapAttrs' (zoneName: zone:
      nameValuePair "20-${zone.interface}" {
        netdevConfig = mkIf (zone.vlanId != null) {
          Kind = "vlan";
          Name = zone.interface;
        };
        vlanConfig = mkIf (zone.vlanId != null) {
          Id = zone.vlanId;
        };
      }
    ) (filterAttrs (n: z: z.vlanId != null) cfg.zones);

    systemd.network.networks = mkMerge [
      # VLAN parent (bridge) - attach VLANs to bridge
      (mapAttrs' (zoneName: zone:
        nameValuePair "40-${zone.interface}" (mkIf (zone.vlanId != null) {
          matchConfig.Name = zone.interface;
          networkConfig.Address = "${zone.gateway}/${
            last (splitString "/" zone.subnet)
          }";
          vlan = [zone.interface];
          linkConfig.RequiredForOnline = "no";
        })
      ) (filterAttrs (n: z: z.vlanId != null) cfg.zones))

      # Update LAN bridge to support VLANs
      {
        "30-lan-bridge" = {
          vlan = mapAttrsToList (n: z: z.interface)
            (filterAttrs (n: z: z.vlanId != null) cfg.zones);
        };
      }
    ];

    ############################################################
    # DHCP & DNS per zone (dnsmasq)
    ############################################################
    services.dnsmasq.settings = mkMerge [
      {
        # Listen on all zone interfaces
        interface = mapAttrsToList (n: z: z.interface) cfg.zones;

        # DHCP options per zone
        dhcp-option = flatten (mapAttrsToList (zoneName: zone: let
          # DNS servers: use custom if specified, otherwise use gateway
          dnsServers = if zone.dns.servers != null
            then concatStringsSep "," zone.dns.servers
            else zone.gateway;
        in [
          "tag:${zone.interface},option:router,${zone.gateway}"
          "tag:${zone.interface},option:dns-server,${dnsServers}"
        ]) cfg.zones);

        # Static DHCP leases per zone
        dhcp-host = flatten (mapAttrsToList (zoneName: zone:
          map (lease: let
            hostnameField = optionalString (lease.hostname != null) ",${lease.hostname}";
          in
            "${lease.mac},${lease.ip}${hostnameField}"
          ) zone.dhcp.staticLeases
        ) cfg.zones);
      }

      # Zone DHCP ranges
      allZoneDHCP
    ];

    ############################################################
    # Zone-based firewall (nftables)
    ############################################################
    networking.nftables.ruleset = mkAfter (let
      # Get all zones that use a custom DNS server (not their own gateway)
      zonesWithCustomDNS = filter (zoneName: let
        zone = cfg.zones.${zoneName};
      in zone.dns.servers != null && zone.dns.servers != []) (attrNames cfg.zones);

      # Generate DNS access rules for zones with custom DNS servers
      dnsAccessRules = concatMapStrings (zoneName: let
        zone = cfg.zones.${zoneName};
        dnsIPs = concatStringsSep ", " zone.dns.servers;
      in ''
        # ${zoneName} -> DNS servers (${dnsIPs})
        iifname "${zone.interface}" ip daddr { ${dnsIPs} } udp dport 53 accept
        iifname "${zone.interface}" ip daddr { ${dnsIPs} } tcp dport 53 accept
      '') zonesWithCustomDNS;
    in ''
      # Zone-based firewall rules
      table inet zones {
        ${concatMapStrings (zoneName: mkZoneSet zoneName cfg.zones.${zoneName}) (attrNames cfg.zones)}

        chain input {
          type filter hook input priority 1; policy accept;

          # Allow router services on all zone interfaces
          ${concatMapStrings (zoneName: let
            zone = cfg.zones.${zoneName};
          in ''
            iifname "${zone.interface}" accept
          '') (attrNames cfg.zones)}
        }

        chain forward {
          type filter hook forward priority 1; policy drop;

          ct state { established, related } accept

          # Allow port forwarding from WAN to LAN
          # (Port forward rules are in core router module, this allows them through zones)
          iifname "${routerCfg.wan.interface}" oifname "${cfg.zones.lan.interface}" accept

          # DNS access for zones with custom DNS servers
          ${dnsAccessRules}

          # Zone -> WAN (internet access)
          ${mkZoneToWanRules}

          # Inter-zone routing
          ${mkInterZoneRules}

          # Isolation enforcement
          ${concatMapStrings (zoneName: let
            zone = cfg.zones.${zoneName};
          in
            optionalString (zone.isolation == "partial") ''
              # ${zoneName}: partial isolation (can access LAN only)
              iifname "${zone.interface}" oifname "${cfg.zones.lan.interface}" accept
            ''
            + optionalString (zone.isolation == "none") ''
              # ${zoneName}: no isolation (can access all zones)
              iifname "${zone.interface}" accept
            ''
          ) (attrNames cfg.zones)}
        }

        ${cfg.extraFirewallRules}
      }
    '');

    ############################################################
    # Helpful scripts
    ############################################################
    environment.systemPackages = [
      (pkgs.writeScriptBin "router-zones" ''
        #!${pkgs.bash}/bin/bash
        echo "=== Network Zones ==="
        echo ""
        ${concatMapStrings (zoneName: let
          zone = cfg.zones.${zoneName};
        in ''
          echo "Zone: ${zoneName}"
          echo "  Interface: ${zone.interface}"
          echo "  VLAN: ${if zone.vlanId != null then toString zone.vlanId else "native/untagged"}"
          echo "  Subnet: ${zone.subnet}"
          echo "  Gateway: ${zone.gateway}"
          echo "  Internet: ${if zone.allowInternet then "allowed" else "blocked"}"
          echo "  Isolation: ${zone.isolation}"
          ${optionalString (zone.description != "") ''
            echo "  Description: ${zone.description}"
          ''}
          echo ""
        '') (attrNames cfg.zones)}
        echo "=== Inter-Zone Routes ==="
        ${if cfg.interZoneRoutes != [] then
          concatMapStrings (rule: let
            protoStr = if rule.protocol != null then " [${rule.protocol}]" else "";
            portsStr =
              if rule.ports != null && rule.ports != []
              then " ports: ${concatMapStringsSep "," toString rule.ports}"
              else if rule.portRanges != null && rule.portRanges != []
              then " ports: ${concatMapStringsSep "," (r: "${toString r.start}-${toString r.end}") rule.portRanges}"
              else "";
            destIPStr =
              if rule.destinationIPs != null && rule.destinationIPs != []
              then " -> ${concatStringsSep "," rule.destinationIPs}"
              else "";
            descStr = optionalString (rule.description != "") " (${rule.description})";
          in ''
            echo "${rule.from} -> ${concatStringsSep ", " rule.to}${protoStr}${portsStr}${destIPStr}${descStr}"
          '') cfg.interZoneRoutes
        else ''
          echo "No custom inter-zone routes configured"
        ''}
      '')
    ];
  };
}
