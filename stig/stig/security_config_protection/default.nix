{ lib, config, pkgs, ... }:
with lib;
with lib.fmf;

mkStigModule {
  inherit config;
  name = "security_config_protection";
  srgList = [
    "SRG-OS-000058-GPOS-00028"
    "SRG-OS-000059-GPOS-00029"
    "SRG-OS-000063-GPOS-00032"
    "SRG-OS-000066-GPOS-00034"
  ];
  cciList = [ "CCI-000163" "CCI-000164" "CCI-000171" ];
  stigConfig = {
    # Prevent unauthorized changes to login UIDs
    security.audit.rules = [ "--loginuid-immutable" ];

    # Enforce system file permissions (max 0644 for files, 0755 for directories)
    systemd.tmpfiles.rules =
      [ "z /etc/nixos 0755 root root -" "z /etc/nixos/* 0644 root root -" ];
  };
}
