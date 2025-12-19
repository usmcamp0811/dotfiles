{ lib, config, pkgs, ... }:
with lib;
with lib.fmf;

mkStigModule {
  inherit config;
  name = "audit_unsuccessful_file_access";
  srgList = [ "SRG-OS-000042-GPOS-00020" "SRG-OS-000461-GPOS-00205" ];
  cciList = [ "CCI-000135" "CCI-000172" ];
  stigConfig = {
    security.audit.rules = [
      "-a always,exit -F arch=b32 -S open,creat,truncate,ftruncate,openat,open_by_handle_at -F exit=-EACCES -F auid>=1000 -F auid!=unset -F key=access"
      "-a always,exit -F arch=b32 -S open,creat,truncate,ftruncate,openat,open_by_handle_at -F exit=-EPERM -F auid>=1000 -F auid!=unset -F key=access"
      "-a always,exit -F arch=b64 -S open,creat,truncate,ftruncate,openat,open_by_handle_at -F exit=-EACCES -F auid>=1000 -F auid!=unset -F key=access"
      "-a always,exit -F arch=b64 -S open,creat,truncate,ftruncate,openat,open_by_handle_at -F exit=-EPERM -F auid>=1000 -F auid!=unset -F key=access"
    ];
  };
}
