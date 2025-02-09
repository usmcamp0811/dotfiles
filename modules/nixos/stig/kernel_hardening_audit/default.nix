{ lib, config, pkgs, ... }:
with lib;
with lib.campground;

mkStigModule {
  inherit config;
  name = "kernel_hardening_audit";
  srgList = [
    "SRG-OS-000433-GPOS-00192"
    "SRG-OS-000132-GPOS-00067"
    "SRG-OS-000433-GPOS-00193"
    "SRG-OS-000437-GPOS-00194"
    "SRG-OS-000463-GPOS-00207"
  ];
  cciList = [ "CCI-002824" "CCI-001082" "CCI-002617" ];
  stigConfig = {
    # Prevent Internal Kernel Address Leakage
    boot.kernel.sysctl."kernel.kptr_restrict" = 1;

    # Enable ASLR for Memory Protection
    boot.kernel.sysctl."kernel.randomize_va_space" = 2;

    # Configure Audit Logging for Security Object Modifications
    security.audit.rules = [
      "-a always,exit -F arch=b64 -S setxattr -F key=audit_secobj"
      "-a always,exit -F arch=b64 -S lsetxattr -F key=audit_secobj"
      "-a always,exit -F arch=b64 -S fsetxattr -F key=audit_secobj"
      "-a always,exit -F arch=b64 -S removexattr -F key=audit_secobj"
      "-a always,exit -F arch=b64 -S lremovexattr -F key=audit_secobj"
      "-a always,exit -F arch=b64 -S fremovexattr -F key=audit_secobj"
    ];
  };
}
