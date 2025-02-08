{ lib, config, pkgs, ... }:
with lib;
with lib.campground;


mkStigModule {
  inherit config;
  name = "audit_storage_thresholds";
  srgList = [ "SRG-OS-000046-GPOS-00022" ];
  stigConfig = {
    services.auditd.extraConfig = ''
      space_left = 25%
      admin_space_left = 10%
    '';
  };
}
