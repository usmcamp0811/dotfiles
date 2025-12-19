{ lib, config, pkgs, ... }:
with lib;
with lib.fmf;

mkStigModule {
  inherit config;
  name = "audit_account_modifications";
  srgList = [
    "SRG-OS-000476-GPOS-00221"
    "SRG-OS-000042-GPOS-00020"
    "SRG-OS-000274-GPOS-00104"
    "SRG-OS-000275-GPOS-00105"
    "SRG-OS-000276-GPOS-00106"
    "SRG-OS-000277-GPOS-00107"
    "SRG-OS-000477-GPOS-00222"
    "SRG-OS-000304-GPOS-00121"
  ];
  stigConfig = {
    security.audit.rules = [
      "-w /etc/sudoers -p wa -k identity"
      "-w /etc/passwd -p wa -k identity"
      "-w /etc/shadow -p wa -k identity"
      "-w /etc/gshadow -p wa -k identity"
      "-w /etc/group -p wa -k identity"
      "-w /etc/security/opasswd -p wa -k identity"
    ];
  };
}
