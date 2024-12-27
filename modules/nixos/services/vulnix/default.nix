# -----------------------------------------
# Tags: NIST 800-171, Hardening, Posturing,
# Security, System Audit, Lynis, Vulnix,
# Compliance, Automation, Reports,
# Cybersecurity, Weekly Audit, NixOS Modules
# -----------------------------------------
{ config, pkgs, lib, ... }:

with lib;
with lib.campground;

let cfg = config.campground.services.vulnix;
in {
  options.campground.services.vulnix = with types; {
    enable = mkBoolOpt false "Enable vulnix audit service";
    reportsDir =
      mkOpt str "/var/log/audit-reports" "report and logging base path";
  };

  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.rules = [ "d ${cfg.reportsDir} 0755 root root - -" ];

    systemd.services.vulnix-audit = {
      description = "Run Vulnix system audit weekly";
      wantedBy = [ "timers.target" ];
      serviceConfig = { Type = "oneshot"; };
      environment = { LANG = "C.UTF-8"; };
      script = "${
          pkgs.writeShellScriptBin "service" ''
            	   echo "https://github.com/nix-community/vulnix/issues/79"
            	   echo "Vulnix has poor exit handling"
                       ${pkgs.vulnix}/bin/vulnix --system --json > ${cfg.reportsDir}/vulnix-$(date +%s).json
            	   exit 0
            	''
        }/bin/service";
    };

    systemd.timers.vulnix-audit = {
      description = "Schedule Vulnix system audit weekly";
      timerConfig = {
        OnCalendar = "weekly";
        Persistent = true;
      };
    };
  };
}
