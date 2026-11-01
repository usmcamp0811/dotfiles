# Circuit Breaker (https://github.com/BlkLeg/CircuitBreaker) - declarative homelab
# topology whose *declared* half is derived from this flake.
#
# See docs/CIRCUIT-BREAKER.md for the architecture, operations and limits.
#
#   fmf.services.circuit-breaker = {
#     enable = true;
#     server = {
#       enable = true;
#       domain = "topology.lan.example.com";
#       secrets.generate = true;
#     };
#     flakeSync = {
#       enable = true;
#       inventory.nixosConfigurations = inputs.self.nixosConfigurations;
#       git = { enable = true; url = "https://git.example/me/config.git"; };
#     };
#     monitoring.enable = true;
#   };
#
# The `hints` options below exist on *every* host (they are read by the exporter
# from each system's evaluated configuration) and are inert unless a Circuit
# Breaker server consumes the inventory.
{
  lib,
  config,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.services.circuit-breaker;

  connectionType = types.submodule {
    options = {
      to = mkOption {
        type = types.str;
        description = "Target: a nixosConfigurations name, a hints.devices name, or a full inventory id (host/x, vm/x, device/x).";
      };
      type = mkOpt types.str "ethernet" "Connection type shown on the edge (ethernet, fiber, wifi, usb, ...).";
      bandwidthMbps = mkOpt (types.nullOr types.int) null "Link speed in Mbit/s, if known.";
      label = mkOpt (types.nullOr types.str) null "Free-form label (port numbers, cable id, ...).";
    };
  };

  monitoringHint = types.submodule {
    options.enable = mkOpt (types.nullOr types.bool) null "null = follow the global monitoring policy; false = never monitor this system.";
  };

  deviceType = types.submodule {
    options = {
      displayName = mkOpt (types.nullOr types.str) null "Name shown in Circuit Breaker.";
      role = mkOpt (types.nullOr types.str) null "switch, ap, ups, pdu, nas, firewall, ...";
      vendor = mkOpt (types.nullOr types.str) null "Vendor, e.g. ubiquiti.";
      model = mkOpt (types.nullOr types.str) null "Model name.";
      address = mkOpt (types.nullOr types.str) null "Management IP address (enables reachability monitoring).";
      mac = mkOpt (types.nullOr types.str) null "MAC address (used to match discovered devices).";
      location = mkOpt (types.nullOr types.str) null "Physical location.";
      rack = mkOpt (types.nullOr types.str) null "Rack / unit.";
      tags = mkOpt (types.listOf types.str) [] "Extra classification tags.";
      monitoring = mkOpt monitoringHint {} "Monitoring override.";
      connections = mkOpt (types.listOf connectionType) [] "Explicit physical connections originating at this device.";
    };
  };

  hintsType = types.submodule {
    options = {
      ignore = mkBoolOpt false "Leave this system out of the inventory entirely.";
      displayName = mkOpt (types.nullOr types.str) null "Name shown in Circuit Breaker instead of the host name.";
      role = mkOpt (types.nullOr types.str) null "Device role hint (router, nas, hypervisor, ...); becomes a role: tag.";
      location = mkOpt (types.nullOr types.str) null "Physical location of this machine.";
      rack = mkOpt (types.nullOr types.str) null "Rack position.";
      tags = mkOpt (types.listOf types.str) [] "Extra classification tags.";
      monitoring = mkOpt monitoringHint {} "Monitoring override for this system.";
      connections = mkOpt (types.listOf connectionType) [] ''
        Explicitly declared physical connections. Nothing is ever inferred as a
        cable from a shared subnet; only entries listed here become connects_to edges.
      '';
      services = mkOpt (types.attrsOf (types.submodule {
        options = {
          ignore = mkBoolOpt false "Do not report this service.";
          displayName = mkOpt (types.nullOr types.str) null "Display name.";
          kind = mkOpt (types.nullOr types.str) null "Override the classified kind.";
          url = mkOpt (types.nullOr types.str) null "Canonical URL for this service.";
        };
      })) {} "Per-service overrides keyed by service name (e.g. traefik, postgresql, ssh).";
      extraServices = mkOpt (types.listOf (types.submodule {
        options = {
          name = mkOption {
            type = types.str;
            description = "Service name.";
          };
          kind = mkOpt types.str "application" "Service kind.";
          port = mkOpt (types.nullOr types.port) null "Listening port.";
          protocol = mkOpt (types.enum ["tcp" "udp"]) "tcp" "Transport protocol.";
          url = mkOpt (types.nullOr types.str) null "URL.";
        };
      })) [] "Endpoints on this host that are not NixOS services (appliances, containers managed elsewhere).";
      networks = mkOpt (types.attrsOf (types.submodule {
        options = {
          cidr = mkOption {
            type = types.str;
            description = "Network CIDR.";
          };
          vlanId = mkOpt (types.nullOr types.int) null "VLAN id.";
          gateway = mkOpt (types.nullOr types.str) null "Gateway address.";
          description = mkOpt (types.nullOr types.str) null "Description.";
        };
      })) {} "Networks that are not derivable from interface addresses or router zones.";
      devices = mkOpt (types.attrsOf deviceType) {} ''
        Non-NixOS devices (switches, access points, UPS, appliances) to show on
        the map. Declared here, next to the host that manages them.
      '';
    };
  };

  discoveryProfile = types.submodule {
    options = {
      cidr = mkOption {
        type = types.str;
        example = "10.8.0.0/24";
        description = "Range to scan. Must be private and no wider than a /16 (/48 for IPv6).";
      };
      scanTypes = mkOpt (types.listOf types.str) ["nmap"] "Circuit Breaker scan types.";
      schedule = mkOpt (types.nullOr types.str) null "5-field cron expression; null = never scheduled (manual runs only).";
      nmapArguments = mkOpt (types.nullOr types.str) null "Extra nmap arguments (use to bound rate, e.g. '-T3 --max-rate 100').";
      enable = mkBoolOpt true "Whether the profile is enabled.";
    };
  };
in {
  imports = [./server.nix ./sync.nix ./agent.nix];

  options.fmf.services.circuit-breaker = {
    enable = mkBoolOpt false "Enable Circuit Breaker components on this host (server and/or agent).";

    # `port`/`scheme` follow the convention used by lib.fmf.lookupServiceEndpoint
    # so reverse-proxy configuration can discover the backend.
    port = mkOption {
      type = types.port;
      default = cfg.server.port;
      defaultText = literalExpression "config.fmf.services.circuit-breaker.server.port";
      readOnly = true;
      description = "Backend port for reverse-proxy discovery (the HTTPS port of the server).";
    };
    scheme = mkOption {
      type = types.str;
      default = "https";
      readOnly = true;
      description = "Backend scheme for reverse-proxy discovery. The container only serves the API/UI over HTTPS.";
    };

    hints = mkOption {
      type = hintsType;
      default = {};
      description = ''
        Optional metadata that cannot be derived from the evaluated NixOS
        configuration. These supplement - never replace - the automatic export.
      '';
    };

    monitoring = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Derive Circuit Breaker monitors (ICMP/TCP/HTTP/DNS) from the inventory.";
      };
      intervalSecs = mkOpt types.ints.positive 60 "Check interval.";
      icmp = mkBoolOpt true "ICMP reachability for hosts/VMs/devices with a known address.";
      ssh = mkBoolOpt true "TCP check of the SSH port where SSH is declared and not firewalled.";
      http = mkBoolOpt true "HTTPS checks for services published through the reverse proxy.";
      httpVerifyTls = mkBoolOpt true "Verify TLS certificates in HTTP checks.";
      tcpKinds = mkOpt (types.listOf types.str) ["reverse-proxy" "database" "cache" "dns" "auth" "secrets" "scm" "orchestrator"] "Service kinds that get a TCP check on their first port.";
      dnsQueryName = mkOpt (types.nullOr types.str) null "If set, DNS-kind services are checked by resolving this name.";
      exclude = mkOpt (types.listOf types.str) [] "Inventory ids/globs (with *) that must never be monitored.";
      remoteProbes = mkOpt (types.attrsOf types.str) {} ''
        Run matching monitors from an enrolled agent instead of the server:
        `{ "mon/host/kube-*" = "edge-agent-hostname"; }`. A monitor whose agent is
        not enrolled and approved is skipped, never silently run from the server.
      '';
      discovery = {
        enable = mkBoolOpt false ''
          Explicitly authorise active network discovery for the profiles below.
          Off by default: nothing is scanned unless this is true and a CIDR is listed.
        '';
        profiles = mkOpt (types.attrsOf discoveryProfile) {} "Named discovery profiles.";
        allowPublicRanges = mkBoolOpt false "Allow scanning non-private ranges (not recommended).";
      };
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.server.enable || cfg.agent.enable;
        message = "fmf.services.circuit-breaker.enable is set but neither server.enable nor agent.enable is.";
      }
      {
        assertion = !(cfg.monitoring.discovery.enable && cfg.monitoring.discovery.profiles == {});
        message = "fmf.services.circuit-breaker.monitoring.discovery.enable requires at least one profile (no implicit scanning).";
      }
    ];
  };
}
