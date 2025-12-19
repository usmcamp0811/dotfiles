{ lib, config, pkgs, ... }:
with lib;
with lib.fmf;


mkStigModule {
  inherit config;
  name = "audit_chown_operations";
  srgList = [ "SRG-OS-000042-GPOS-00020" ];
  stigConfig = {
    security.audit.rules = [
      "-a always,exit -F arch=b32 -S lchown,fchown,chown,fchownat -F auid>=1000 -F auid!=unset -F key=perm_mod"
      "-a always,exit -F arch=b64 -S chown,fchown,lchown,fchownat -F auid>=1000 -F auid!=unset -F key=perm_mod"
    ];
  };
}

