{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.services.microvm-healthcheck;

  # Build a mapping of VM names to their IP addresses from static DHCP leases
  # This searches through all zones' static leases to find VMs
  vmIpMapping = let
    # Get all static leases from all router zones
    allLeases =
      if config.fmf.router.zones.enable or false
      then
        lists.flatten (
          lists.forEach (attrValues config.fmf.router.zones.zones) (
            zone:
              zone.dhcp.staticLeases or []
          )
        )
      else [];

    # Filter to only VM hostnames and create a mapping
    vmLeases = filter (lease: hasPrefix "vm-" (lease.hostname or "")) allLeases;
  in
    listToAttrs (
      map (lease: nameValuePair lease.hostname lease.ip) vmLeases
    );

  # Get list of configured VMs
  configuredVms = attrNames (config.microvm.vms or {});

  # Generate the healthcheck script
  healthcheckScript = pkgs.writeShellScript "microvm-healthcheck" ''
    # Configured VMs to monitor
    ${concatMapStringsSep "\n" (vm: ''
        # Check ${vm}
        if ! systemctl is-active --quiet "microvm@${vm}.service"; then
          echo "VM ${vm} is not running, skipping health check"
        else
          ${
      if vmIpMapping ? ${vm}
      then ''
        IP="${vmIpMapping.${vm}}"
        if timeout ${toString cfg.healthCheckTimeout} ${pkgs.netcat}/bin/nc -z "$IP" ${toString cfg.healthCheckPort} 2>/dev/null; then
          echo "VM ${vm} ($IP) is healthy - port ${toString cfg.healthCheckPort} responding"
        else
          echo "VM ${vm} ($IP) is NOT responding on port ${toString cfg.healthCheckPort} - may be stuck"
          ${
          if cfg.autoRestart
          then ''
            echo "Restarting microvm@${vm}.service..."
            systemctl restart "microvm@${vm}.service"
          ''
          else ''
            echo "Auto-restart is disabled, manual intervention required"
          ''
        }
        fi
      ''
      else ''
        echo "WARNING: No IP mapping found for ${vm} in static DHCP leases"
      ''
    }
        fi
      '')
      configuredVms}
  '';
in {
  options.services.microvm-healthcheck = {
    enable = mkEnableOption "MicroVM health check and auto-recovery";

    healthCheckPort = mkOption {
      type = types.port;
      default = 22;
      description = "Port to check for VM health (default: SSH port 22)";
    };

    healthCheckTimeout = mkOption {
      type = types.int;
      default = 5;
      description = "Timeout in seconds for health check probes";
    };

    autoRestart = mkOption {
      type = types.bool;
      default = true;
      description = "Automatically restart unhealthy VMs";
    };

    checkInterval = mkOption {
      type = types.str;
      default = "2min";
      description = "How often to run health checks (systemd time format)";
    };

    bootDelay = mkOption {
      type = types.str;
      default = "5min";
      description = "How long to wait after boot before first health check (systemd time format)";
    };
  };

  config = mkIf cfg.enable {
    systemd.services.microvm-healthcheck = {
      description = "MicroVM Health Check and Auto-Recovery";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = healthcheckScript;
      };
    };

    systemd.timers.microvm-healthcheck = {
      description = "MicroVM Health Check Timer";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnBootSec = cfg.bootDelay;
        OnUnitActiveSec = cfg.checkInterval;
        Unit = "microvm-healthcheck.service";
      };
    };
  };
}
