{ lib, config, pkgs, ... }:
with lib;
with lib.campground;

mkStigModule {
  inherit config;
  name = "syslog_log_permissions";
  srgList = [ "SRG-OS-000057-GPOS-00027" ];
  stigConfig = {
    systemd.tmpfiles.rules = [ "f /var/log/syslog 0640 root root -" ];
  };
}
