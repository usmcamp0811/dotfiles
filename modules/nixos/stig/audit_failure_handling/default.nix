{ lib, config, pkgs, ... }:
with lib;
with lib.campground;

mkStigModule {
  inherit config;
  name = "audit_failure_handling";
  srgList = [ "SRG-OS-000047-GPOS-00023" ];
  cciList = [ "CCI-000140" ];
  stigConfig = {
    services.auditd.extraConfig = ''
      disk_full_action = HALT
      disk_error_action = HALT
    '';
  };
}
