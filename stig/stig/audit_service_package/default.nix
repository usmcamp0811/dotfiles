{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
mkStigModule {
  inherit config;
  name = "audit_service_package";
  srgList = [
    "SRG-OS-000037-GPOS-00015"
    "SRG-OS-000038-GPOS-00016"
    "SRG-OS-000039-GPOS-00017"
    "SRG-OS-000040-GPOS-00018"
    "SRG-OS-000041-GPOS-00019"
    "SRG-OS-000042-GPOS-00021"
    "SRG-OS-000054-GPOS-00025"
    "SRG-OS-000055-GPOS-00026"
    "SRG-OS-000058-GPOS-00028"
    "SRG-OS-000059-GPOS-00029"
    "SRG-OS-000239-GPOS-00089"
    "SRG-OS-000240-GPOS-00090"
    "SRG-OS-000241-GPOS-00091"
    "SRG-OS-000255-GPOS-00096"
    "SRG-OS-000303-GPOS-00120"
    "SRG-OS-000327-GPOS-00127"
  ];
  cciList = [
    "CCI-000130"
    "CCI-000131"
    "CCI-000132"
    "CCI-000133"
    "CCI-000134"
    "CCI-000135"
    "CCI-000158"
    "CCI-000159"
    "CCI-000163"
    "CCI-000164"
    "CCI-001403"
    "CCI-001404"
    "CCI-001405"
    "CCI-001487"
    "CCI-002130"
    "CCI-002234"
  ];
  stigConfig = { environment.systemPackages = [ pkgs.audit ]; };
}
