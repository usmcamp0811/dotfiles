{ lib, config, pkgs, ... }:
with lib;
with lib.campground;

mkStigModule {
  inherit config;
  name = "syslog_ng_directory_permissions";
  srgList = [ "SRG-OS-000057-GPOS-00027" ];
  cciList = [ "CCI-000162" ];
  stigConfig = {
    services.syslog-ng.extraConfig = ''
      options {
        dir_perm(0750);
      };
    '';
  };
}
