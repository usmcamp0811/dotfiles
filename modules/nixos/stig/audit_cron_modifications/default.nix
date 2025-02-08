{ lib, config, pkgs, ... }:
with lib;
with lib.campground;

mkStigModule {
  inherit config;
  name = "audit_cron_modifications";
  srgList = [ "SRG-OS-000042-GPOS-00020" ];
  cciList = [ "CCI-000135" ];
  stigConfig = {
    security.audit.rules = [
      "-w /var/cron/tabs/ -p wa -k services"
      "-w /var/cron/cron.allow -p wa -k services"
      "-w /var/cron/cron.deny -p wa -k services"
    ];
  };
}

