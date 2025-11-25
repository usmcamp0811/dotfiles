{ lib, config, pkgs, ... }:
with lib;
with lib.campground;

mkStigModule {
  inherit config;
  name = "audit_pre_daemon";
  srgList = [ "SRG-OS-000042-GPOS-00020" ];
  cciList = [ "CCI-000135" ];
  stigConfig = { boot.kernelParams = [ "audit=1" ]; };
}

