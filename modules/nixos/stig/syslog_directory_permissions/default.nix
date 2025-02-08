{ lib, config, pkgs, ... }:
with lib;
with lib.campground;

mkStigModule {
  inherit config;
  name = "syslog_directory_permissions";
  srgList = [ "SRG-OS-000057-GPOS-00027" ];
  stigConfig = {
    systemd.tmpfiles.rules =
      [ "d /var/log 0700 root root -" "d /var/log/syslog 0700 root root -" ];
  };
}
