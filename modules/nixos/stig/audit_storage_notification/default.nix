{ lib, config, pkgs, ... }:
with lib;
with lib.campground;

mkStigModule {
  inherit config;
  name = "audit_storage_notification";
  srgList = [ "SRG-OS-000046-GPOS-00022" "SRG-OS-000343-GPOS-00134" ];
  cciList = [ "CCI-000139" "CCI-001855" ];
  stigConfig = {
    services.auditd.extraConfig = ''
      space_left_action = syslog
      admin_space_left_action = syslog
      action_mail_acct = root@localhost
    '';
  };
}
