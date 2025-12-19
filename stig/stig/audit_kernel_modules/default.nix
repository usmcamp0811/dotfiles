{ lib, config, pkgs, ... }:
with lib;
with lib.fmf;

mkStigModule {
  inherit config;
  name = "audit_kernel_modules";
  srgList = [ "SRG-OS-000042-GPOS-00020" ];
  stigConfig = {
    security.audit.rules = [
      "-a always,exit -F arch=b32 -S init_module,finit_module,delete_module -F auid>=1000 -F auid!=unset -k module-change"
      "-a always,exit -F arch=b64 -S init_module,finit_module,delete_module -F auid>=1000 -F auid!=unset -k module-change"
    ];
  };
}
