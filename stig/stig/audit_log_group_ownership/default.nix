{ lib, config, pkgs, ... }:
with lib;
with lib.fmf;

mkStigModule {
  inherit config;
  name = "audit_log_group_ownership";
  srgList = [ "SRG-OS-000057-GPOS-00027" "SRG-OS-000206-GPOS-00084" ];
  cciList = [ "CCI-000162" "CCI-001314" ];
  stigConfig = {
    systemd.tmpfiles.rules = [
      "d /var/log/audit 0700 root root -"
      "f /var/log/audit/audit.log 0600 root root -"
      "Z /var/log/audit -g root"
      "Z /var/log/audit/audit.log -g root"
    ];
  };
}
