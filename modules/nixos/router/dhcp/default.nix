# DHCP Server with static lease management
{
  config,
  lib,
  pkgs,
  namespace,
  ...
}:
with lib;
with lib.campground; let
  cfg = config.campground.router.dhcp;
  routerCfg = config.campground.router;

  # Helper to extract network and broadcast from subnet
  subnetInfo = let
    parts = splitString "/" routerCfg.lan.subnet;
    network = head parts;
  in {
    inherit network;
    cidr = last parts;
  };

  staticLeaseType = types.submodule {
    options = {
      hostname = mkOption {
        type = types.str;
        description = "Hostname for the device";
        example = "my-laptop";
      };

      mac = mkOption {
        type = types.str;
        description = "MAC address of the device";
        example = "00:11:22:33:44:55";
      };

      ip = mkOption {
        type = types.str;
        description = "Static IP address to assign";
        example = "192.168.1.100";
      };

      description = mkOption {
        type = types.str;
        default = "";
        description = "Optional description of the device";
        example = "John's laptop";
      };
    };
  };
in {
  options.campground.router.dhcp = {
    enable = mkEnableOption "DHCP server" // {default = routerCfg.enable;};

    poolStart = mkOption {
      type = types.str;
      description = "Start of DHCP pool";
      example = "192.168.1.100";
    };

    poolEnd = mkOption {
      type = types.str;
      description = "End of DHCP pool";
      example = "192.168.1.250";
    };

    leaseTime = mkOption {
      type = types.int;
      default = 86400; # 24 hours
      description = "DHCP lease time in seconds";
    };

    staticLeases = mkOption {
      type = types.listOf staticLeaseType;
      default = [];
      description = "List of static DHCP leases";
      example = literalExpression ''
        [
          {
            hostname = "desktop";
            mac = "00:11:22:33:44:55";
            ip = "192.168.1.10";
            description = "Main desktop computer";
          }
          {
            hostname = "server";
            mac = "AA:BB:CC:DD:EE:FF";
            ip = "192.168.1.20";
            description = "Home server";
          }
        ]
      '';
    };

    extraOptions = mkOption {
      type = types.lines;
      default = "";
      description = "Extra Kea DHCP configuration options";
    };
  };

  config = mkIf (routerCfg.enable && cfg.enable) {
    # Use Kea DHCP server (modern, actively maintained)
    services.kea.dhcp4 = {
      enable = true;
      settings = {
        interfaces-config = {
          interfaces = ["br-lan"];
          dhcp-socket-type = "raw";
        };

        lease-database = {
          type = "memfile";
          persist = true;
          name = "/var/lib/kea/dhcp4.leases";
        };

        valid-lifetime = cfg.leaseTime;
        renew-timer = cfg.leaseTime / 2;
        rebind-timer = cfg.leaseTime * 7 / 8;

        subnet4 = [
          {
            subnet = routerCfg.lan.subnet;
            pools = [
              {
                pool = "${cfg.poolStart} - ${cfg.poolEnd}";
              }
            ];

            option-data = [
              {
                name = "routers";
                data = routerCfg.lan.gateway;
              }
              {
                name = "domain-name-servers";
                data = routerCfg.lan.gateway;
              }
              {
                name = "domain-name";
                data = "lan";
              }
            ];

            # Static reservations
            reservations =
              map (lease: {
                hostname = lease.hostname;
                hw-address = lease.mac;
                ip-address = lease.ip;
              })
              cfg.staticLeases;
          }
        ];

        loggers = [
          {
            name = "kea-dhcp4";
            output_options = [
              {
                output = "stdout";
              }
            ];
            severity = "INFO";
          }
        ];
      };
    };

    # Open DHCP ports on LAN
    networking.firewall.interfaces."br-lan" = {
      allowedUDPPorts = [67 68];
    };

    # Create a convenient script to show current DHCP leases
    environment.systemPackages = [
      (pkgs.writeScriptBin "show-dhcp-leases" ''
        #!${pkgs.bash}/bin/bash
        echo "=== DHCP Leases ==="
        echo ""
        if [ -f /var/lib/kea/dhcp4.leases ]; then
          ${pkgs.jq}/bin/jq -r '.[] | "\(.ip-address)\t\(.hostname // "unknown")\t\(.hw-address)"' /var/lib/kea/dhcp4.leases | column -t
        else
          echo "No leases file found"
        fi
        echo ""
        echo "=== Static Leases (configured) ==="
        ${concatMapStringsSep "\n" (lease: ''
            echo "${lease.ip}\t${lease.hostname}\t${lease.mac}\t${lease.description}"
          '')
          cfg.staticLeases} | column -t
      '')

      (pkgs.writeScriptBin "show-router-config" ''
        #!${pkgs.bash}/bin/bash
        echo "=== Router Configuration ==="
        echo ""
        echo "WAN Interface: ${routerCfg.wan.interface}"
        echo "LAN Interfaces: ${concatStringsSep ", " routerCfg.lan.interfaces}"
        echo "LAN Subnet: ${routerCfg.lan.subnet}"
        echo "LAN Gateway: ${routerCfg.lan.gateway}"
        echo "DHCP Pool: ${cfg.poolStart} - ${cfg.poolEnd}"
        echo ""
        echo "=== Static Leases ==="
        ${concatMapStringsSep "\n" (lease: ''
            echo "${lease.ip}\t${lease.hostname}\t${lease.mac}\t${lease.description}"
          '')
          cfg.staticLeases} | column -t
      '')
    ];
  };
}
