{ lib, config, pkgs, ... }:
with lib;
with lib.fmf;


mkStigModule {
  inherit config;
  name = "audit_log_ownership";
  srgList = [ "SRG-OS-000057-GPOS-00027" ];
  stigConfig = {
    systemd.tmpfiles.rules = [
      "d /var/log/audit 0700 root root -"
      "f /var/log/audit/audit.log 0600 root root -"
    ];
  };
}
