{ lib, config, pkgs, ... }:
with lib;
with lib.campground;

mkStigModule {
  inherit config;
  name = "audit_account_events";
  srgList = [
    "SRG-OS-000473-GPOS-00218"
    "SRG-OS-000042-GPOS-00020"
    "SRG-OS-000475-GPOS-00220"
    "SRG-OS-000476-GPOS-00221"
  ];
  cciList = [ "CCI-000172" "CCI-000135" ];
  stigConfig = {
    # Enable Audit Logging for account events
    security.audit.rules = [
      # Watch lastlog for login tracking
      "-w /var/log/lastlog -p wa -k logins"

      # Watch for user account creations/modifications/disabling/termination
      "-w /etc/passwd -p wa -k identity"
      "-w /etc/shadow -p wa -k identity"
      "-w /etc/group -p wa -k identity"
      "-w /etc/gshadow -p wa -k identity"
      "-w /etc/security/opasswd -p wa -k identity"
    ];
  };
}
