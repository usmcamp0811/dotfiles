{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
mkStigModule {
  inherit config;
  name = "audit_privileged_commands";
  srgList = [ "SRG-OS-000042-GPOS-00020" ];
  stigConfig = { services.auditd.enable = true; };
}
