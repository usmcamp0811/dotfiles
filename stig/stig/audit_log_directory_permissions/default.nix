{ lib, config, pkgs, ... }:
with lib;
with lib.campground;

mkStigModule {
  inherit config;
  name = "audit_log_directory_permissions";
  srgList = [ "SRG-OS-000057-GPOS-00027" ];
  cciList = [ "CCI-000162" ];
  stigConfig = {
    systemd.tmpfiles.rules = [ "d /var/log/audit 0700 root root -" ];
  };
}
