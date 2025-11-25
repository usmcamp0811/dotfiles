{ lib, config, pkgs, ... }:
with lib;
with lib.campground;

mkStigModule {
  inherit config;
  name = "syslog_ng_permissions";
  srgList = [ "SRG-OS-000057-GPOS-00027" "SRG-OS-000205-GPOS-00083" ];
  cciList = [ "CCI-000162" "CCI-001312" ];
  stigConfig = {
    services.syslog-ng.extraConfig = ''
      options {
        dir_perm(0750);
        perm(0640);
      };
    '';
  };
}
