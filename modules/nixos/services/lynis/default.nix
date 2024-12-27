# -----------------------------------------
# Tags: NIST 800-171, Hardening, Posturing,
# Security, System Audit, Lynis, Vulnix,
# Compliance, Automation, Reports,
# Cybersecurity, Weekly Audit, NixOS Modules
# -----------------------------------------
{ config, pkgs, lib, ... }:

with lib;
with lib.campground;

let cfg = config.campground.services.lynis;
in {
  options.campground.services.lynis = with types; {
    enable = mkBoolOpt false "Enable Lynis audit service";
    reportsDir =
      mkOpt str "/var/log/audit-reports" "report and logging base path";
  };
  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.rules = [ "d ${cfg.reportsDir} 0755 root root - -" ];
    systemd.services.lynis-audit = {
      description = "Run Lynis system audit weekly";
      serviceConfig = { Type = "oneshot"; };
      wantedBy = [ "timers.target" ];
      script = ''
              	CURRENTDATETIME=$(date +%s)
              	${pkgs.lynis}/bin/lynis audit system --report-file ${cfg.reportsDir}/lynis-report-$CURRENTDATETIME.dat --log-file ${cfg.reportsDir}/lynis-log-$CURRENTDATETIME.log | ${pkgs.ansi2html}/bin/ansi2html -la > ${cfg.reportsDir}/lynis-report-$CURRENTDATETIME.html
        	'';
      path = with pkgs; [ ps busybox ];
    };
    systemd.timers.lynis-audit = {
      description = "Schedule Lynis system audit weekly";
      timerConfig = {
        OnCalendar = "weekly";
        Persistent = true;
      };
    };
  };
}
