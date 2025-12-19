{ lib, config, pkgs, ... }:
with lib;
with lib.fmf;

mkStigModule {
  inherit config;
  name = "audit_chmod_operations";
  srgList = [ "SRG-OS-000042-GPOS-00020" "SRG-OS-000462-GPOS-00206" ];
  cciList = [ "CCI-000135" "CCI-000172" ];
  stigConfig = {
    security.audit.rules = [
      "-a always,exit -F arch=b32 -S chmod,fchmod,fchmodat -F auid>=1000 -F auid!=unset -F key=perm_mod"
      "-a always,exit -F arch=b64 -S chmod,fchmod,fchmodat -F auid>=1000 -F auid!=unset -F key=perm_mod"
    ];
  };
}
