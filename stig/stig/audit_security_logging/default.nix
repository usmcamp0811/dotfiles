{ lib, config, pkgs, ... }:
with lib;
with lib.campground;

mkStigModule {
  inherit config;
  name = "audit_security_logging";
  srgList = [
    "SRG-OS-000463-GPOS-00207"
    "SRG-OS-000042-GPOS-00020"
    "SRG-OS-000458-GPOS-00203"
    "SRG-OS-000474-GPOS-00219"
    "SRG-OS-000466-GPOS-00210"
    "SRG-OS-000468-GPOS-00212"
    "SRG-OS-000473-GPOS-00218"
  ];
  cciList = [ "CCI-000172" "CCI-000135" ];
  stigConfig = {
    # Enable Audit Logging
    security.audit.rules = [
      # Log modifications to security objects (Extended Attributes)
      "-a always,exit -F arch=b32 -S setxattr,fsetxattr,lsetxattr,removexattr,fremovexattr,lremovexattr -F auid>=1000 -F auid!=-1 -k perm_mod"
      "-a always,exit -F arch=b32 -S setxattr,fsetxattr,lsetxattr,removexattr,fremovexattr,lremovexattr -F auid=0 -k perm_mod"
      "-a always,exit -F arch=b64 -S setxattr,fsetxattr,lsetxattr,removexattr,fremovexattr,lremovexattr -F auid>=1000 -F auid!=-1 -k perm_mod"
      "-a always,exit -F arch=b64 -S setxattr,fsetxattr,lsetxattr,removexattr,fremovexattr,lremovexattr -F auid=0 -k perm_mod"

      # Log privilege deletions
      "-a always,exit -F path=/run/current-system/sw/bin/usermod -F perm=x -F auid>=1000 -F auid!=unset -k privileged-usermod"

      # Log security object deletions
      "-a always,exit -F path=/run/current-system/sw/bin/chage -F perm=x -F auid>=1000 -F auid!=unset -k privileged-chage"
      "-a always,exit -F path=/run/current-system/sw/bin/chcon -F perm=x -F auid>=1000 -F auid!=unset -k perm_mod"

      # Log concurrent logins to the same account from different sources
      "-w /var/log/auth.log -p wa -k auth"
      "-w /var/log/secure -p wa -k auth"
    ];
  };
}
