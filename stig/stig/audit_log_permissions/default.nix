{ lib, config, pkgs, ... }:
with lib;
with lib.fmf;
mkStigModule {
  inherit config;
  name = "audit_log_permissions";
  srgList = [ "SRG-OS-000057-GPOS-00027" "SRG-OS-000206-GPOS-00084" ];
  cciList = [ "CCI-000162" "CCI-001314" ];
  stigConfig = {
    environment.etc."audit/auditd.conf".text = ''
      log_group = root
    '';
  };
}
