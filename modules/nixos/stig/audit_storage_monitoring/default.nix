{ lib, config, pkgs, ... }:
with lib;
with lib.campground;

mkStigModule {
  inherit config;
  name = "audit_storage_monitoring";
  srgList = [ "SRG-OS-000046-GPOS-00022" ];
  stigConfig = {
    services.auditd.extraConfig = ''
      space_left_action = email
      action_mail_acct = root
      admin_space_left_action = halt
    '';
  };
}
