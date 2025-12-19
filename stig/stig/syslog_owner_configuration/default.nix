{ lib, config, pkgs, ... }:
with lib;
with lib.fmf;

mkStigModule {
  inherit config;
  name = "syslog_owner_configuration";
  srgList = [ "SRG-OS-000057-GPOS-00027" "SRG-OS-000206-GPOS-00084" ];
  cciList = [ "CCI-000162" "CCI-001314" ];
  stigConfig = {
    services.syslog-ng.extraConfig = ''
      options {
        owner(root);
        dir_owner(root);
      };
    '';
  };
}
