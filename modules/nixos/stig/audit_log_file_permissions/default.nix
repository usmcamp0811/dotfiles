{ lib, config, pkgs, ... }:
with lib;
with lib.campground;

mkStigModule {
  inherit config;
  name = "audit_log_file_permissions";
  srgList = [ "SRG-OS-000057-GPOS-00027" "SRG-OS-000206-GPOS-00084" ];
  cciList = [ "CCI-000162" "CCI-001314" ];
  stigConfig = {
    systemd.tmpfiles.rules = [ "f /var/log/audit/audit.log 0600 root root -" ];
  };
}
