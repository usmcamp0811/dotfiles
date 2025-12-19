{ lib, config, pkgs, ... }:
with lib;
with lib.fmf;

mkStigModule {
  inherit config;
  name = "fips_compliant_ciphers";
  srgList = [
    "SRG-OS-000033-GPOS-00014"
    "SRG-OS-000250-GPOS-00093"
    "SRG-OS-000394-GPOS-00174"
  ];
  cciList = [ "CCI-000068" "CCI-001453" "CCI-003123" ];
  stigConfig = {
    services.openssh.settings.Ciphers =
      [ "aes256-ctr" "aes192-ctr" "aes128-ctr" ];
  };
}
