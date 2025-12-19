{ lib, config, pkgs, ... }:
with lib;
with lib.fmf;

mkStigModule {
  inherit config;
  name = "audit_storage_monitoring";
  srgList = [
    "SRG-OS-000046-GPOS-00022"
    "SRG-OS-000343-GPOS-00134"
    "SRG-OS-000047-GPOS-00023"
  ];
  stigConfig = {
    environment.etc."audit/auditd.conf".text = ''
      # Notify system administrators when audit storage usage reaches thresholds
      space_left = 25%                  # Action at 75% storage usage
      space_left_action = syslog         # Notify SA/ISSO at 75%

      admin_space_left = 10%             # Action at 90% storage usage
      admin_space_left_action = syslog   # Notify SA/ISSO at 90%

      disk_full_action = HALT            # Stop system if storage is full
      disk_error_action = HALT           # Stop system if audit process fails
    '';
  };
}
