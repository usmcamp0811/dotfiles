{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
mkStigModule {
  inherit config;
  name = "audit";
  srgList = [
    "SRG-OS-000004-GPOS-00004"
    "SRG-OS-000254-GPOS-00095"
    "SRG-OS-000344-GPOS-00135"
    "SRG-OS-000348-GPOS-00136"
    "SRG-OS-000349-GPOS-00137"
    "SRG-OS-000350-GPOS-00138"
    "SRG-OS-000351-GPOS-00139"
    "SRG-OS-000352-GPOS-00140"
    "SRG-OS-000353-GPOS-00141"
    "SRG-OS-000354-GPOS-00142"
    "SRG-OS-000122-GPOS-00063"
    "SRG-OS-000358-GPOS-00145"
  ];
  cciList = [
    "CCI-000018"
    "CCI-001464"
    "CCI-001858"
    "CCI-001875"
    "CCI-001877"
    "CCI-001878"
    "CCI-001879"
    "CCI-001880"
    "CCI-001881"
    "CCI-001882"
    "CCI-001876"
    "CCI-001889"
  ];
  extraConfig = {
    security.auditd.enable = mkForce true;
    security.audit.enable = mkForce true;
  };
}
