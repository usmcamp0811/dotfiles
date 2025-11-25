{ lib, config, pkgs, ... }:
with lib;
with lib.campground;

mkStigModule {
  inherit config;
  name = "audit_mount_syscall";
  srgList = [ "SRG-OS-000042-GPOS-00020" ];
  cciList = [ "CCI-000135" ];
  stigConfig = {
    security.audit.rules = [
      "-a always,exit -F arch=b32 -S mount -F auid>=1000 -F auid!=unset -k privileged-mount"
      "-a always,exit -F arch=b64 -S mount -F auid>=1000 -F auid!=unset -k privileged-mount"
    ];
  };
}

