{ lib, config, pkgs, ... }:
with lib;
with lib.fmf;

mkStigModule {
  inherit config;
  name = "session_lock_package";
  srgList = [
    "SRG-OS-000030-GPOS-00011"
    "SRG-OS-000028-GPOS-00009"
    "SRG-OS-000031-GPOS-00012"
  ];
  cciList = [ "CCI-000057" "CCI-000056" "CCI-000060" ];
  stigConfig = { environment.systemPackages = [ pkgs.vlock ]; };
}
