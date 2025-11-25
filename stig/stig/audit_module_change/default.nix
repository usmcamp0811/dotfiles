{ lib, config, pkgs, ... }:
with lib;
with lib.campground;

mkStigModule {
  inherit config;
  name = "audit_module_change";
  srgList = [ "SRG-OS-000042-GPOS-00020" "SRG-OS-000471-GPOS-00216" ];
  cciList = [ "CCI-000135" "CCI-000172" ];
  stigConfig = {
    security.audit.rules = [
      "-a always,exit -F arch=b32 -S init_module,finit_module,delete_module -F auid>=1000 -F auid!=unset -k module_chng"
      "-a always,exit -F arch=b64 -S init_module,finit_module,delete_module -F auid>=1000 -F auid!=unset -k module_chng"
    ];
  };
}
