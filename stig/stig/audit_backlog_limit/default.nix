{ lib, config, pkgs, ... }:
with lib;
with lib.campground;


mkStigModule {
  inherit config;
  name = "audit_backlog_limit";
  srgList = [ "SRG-OS-000042-GPOS-00020" ];
  stigConfig = { boot.kernelParams = [ "audit_backlog_limit=8192" ]; };
}
