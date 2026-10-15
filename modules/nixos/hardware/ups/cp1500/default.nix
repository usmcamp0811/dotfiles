{config, lib, pkgs, ...}:
with lib;
with lib.fmf; let
  cfg = config.fmf.hardware.ups.cp1500;
  prefix = "ups-${cfg.name}";
  stateDir = "/var/lib/${prefix}-events";
  actions = filterAttrs (_: action: action.script != "") ({
    power-loss = {script = cfg.onPowerLoss;};
    power-restored = {script = cfg.onPowerRestored;};
    low-battery = {script = cfg.onLowBattery;};
  } // mapAttrs' (name: action: nameValuePair "battery-${name}" {
    inherit (action) script;
    threshold = action.percent;
  }) cfg.batteryActions);
  monitorConfig = pkgs.writeText "${prefix}-events.json" (builtins.toJSON {
    ups = "${cfg.name}@127.0.0.1";
    inherit stateDir;
    upsc = "${config.power.ups.package}/bin/upsc";
    systemctl = "${pkgs.systemd}/bin/systemctl";
    actions = mapAttrs (name: action: {
      unit = "${prefix}-${name}.service";
    } // optionalAttrs (action ? threshold) {inherit (action) threshold;}) actions;
  });
in {
  options.fmf.hardware.ups.cp1500 = with types; {
    enable = mkEnableOption "CyberPower USB HID UPS monitoring and script hooks";
    name = mkOpt (strMatching "[a-zA-Z0-9][a-zA-Z0-9_-]*") "cyberpower" "NUT UPS name and systemd unit prefix.";
    vid = mkOpt (strMatching "[0-9a-fA-F]{4}") "0764" "USB vendor ID.";
    pid = mkOpt (strMatching "[0-9a-fA-F]{4}") "0601" "USB product ID.";
    serial = mkOpt (nullOr str) null "Optional NUT serial matching expression when multiple UPSes have the same USB IDs.";
    pollInterval = mkOpt ints.positive 5 "Seconds between completed UPS checks.";
    hookTimeout = mkOpt str "2min" "Maximum runtime of each hook (systemd duration).";
    extraPackages = mkOpt (listOf package) [] "Extra packages on script hooks' PATH.";
    onPowerLoss = mkOpt lines "" "Script run once when an outage is observed (UPS status OB).";
    onPowerRestored = mkOpt lines "" "Script run when mains power returns after an observed outage (OL).";
    onLowBattery = mkOpt lines "" "Script run once per outage when the UPS reports its native LB flag.";
    batteryActions = mkOpt (attrsOf (submodule {
      options = {
        percent = mkOption {
          type = ints.between 1 100;
          description = "Run when on battery with charge at or below this percentage.";
        };
        script = mkOption {
          type = lines;
          description = "Script to run once per outage at this threshold.";
        };
      };
    })) {} "Named, configurable battery percentage actions; no thresholds are enabled by default.";
  };

  config = mkIf cfg.enable {
    assertions = mapAttrsToList (name: _: {
      assertion = builtins.match "[a-zA-Z0-9][a-zA-Z0-9_-]*" name != null;
      message = "UPS battery action names must use letters, digits, underscores or hyphens, starting with a letter or digit.";
    }) cfg.batteryActions;
    # Use the native NixOS NUT module, not hand-written /etc/nut aliases.
    # Telemetry reads need no password. No upsmon/FSD/shutdown policy is enabled:
    # destructive actions must be explicitly selected in the hooks above.
    power.ups = {
      enable = true;
      mode = "netserver";
      openFirewall = false;
      upsmon = {
        enable = false;
        settings.POWERDOWNFLAG = null;
      };
      upsd.listen = [{address = "127.0.0.1";}];
      ups.${cfg.name} = {
        driver = "usbhid-ups";
        description = "CyberPower USB HID UPS";
        port = "auto";
        directives = ["vendorid = ${cfg.vid}" "productid = ${cfg.pid}"]
          ++ optional (cfg.serial != null) "serial = ${builtins.toJSON cfg.serial}";
      };
    };
    users.groups.nut = {};

    systemd.services = {
      "${prefix}-events" = {
        description = "Observe ${cfg.name} UPS power events";
        wants = ["upsd.service" "upsdrv.service"];
        after = ["upsd.service" "upsdrv.service"];
        serviceConfig = {
          Type = "oneshot";
          StateDirectory = "${prefix}-events";
          StateDirectoryMode = "0700";
          # upsc has a bounded query timeout; each separate hook has its own
          # deadline. Allow several hooks to finish in threshold order.
          TimeoutStartSec = "infinity";
          UMask = "0077";
          ExecStart = "${pkgs.python3}/bin/python3 ${./monitor.py} ${monitorConfig}";
        };
      };
    } // mapAttrs' (name: action: nameValuePair "${prefix}-${name}" {
      description = "${cfg.name} UPS hook: ${name}";
      path = [pkgs.coreutils pkgs.systemd config.power.ups.package] ++ cfg.extraPackages;
      serviceConfig = {
        Type = "oneshot";
        TimeoutStartSec = cfg.hookTimeout;
        EnvironmentFile = "${stateDir}/${name}.env";
        UMask = "0077";
      };
      script = ''
        set -euo pipefail
        ${action.script}
      '';
    }) actions;

    systemd.timers."${prefix}-events" = {
      description = "Poll ${cfg.name} UPS power state";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnBootSec = "30s";
        OnUnitInactiveSec = "${toString cfg.pollInterval}s";
        AccuracySec = "1s";
        Unit = "${prefix}-events.service";
      };
    };
  };
}
