{ lib, config, pkgs, ... }:
with lib;
with lib.fmf;

mkStigModule {
  inherit config;
  name = "remote_access_monitoring";
  srgList = [ "SRG-OS-000032-GPOS-00013" ];
  cciList = [ "CCI-000067" ];
  stigConfig = { services.openssh.logLevel = "VERBOSE"; };
}
