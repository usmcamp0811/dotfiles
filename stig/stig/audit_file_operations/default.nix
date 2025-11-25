{ lib, config, pkgs, ... }:
with lib;
with lib.campground;


mkStigModule {
  inherit config;
  name = "audit_file_operations";
  srgList = [ "SRG-OS-000042-GPOS-00020" ];
  stigConfig = {
    security.audit.rules = [
      "-a always,exit -F arch=b32 -S truncate,ftruncate,creat,open,openat,open_by_handle_at -F auid>=1000 -F auid!=unset -k file_operations"
      "-a always,exit -F arch=b64 -S truncate,ftruncate,creat,open,openat,open_by_handle_at -F auid>=1000 -F auid!=unset -k file_operations"
    ];
  };
}
