{ lib, config, pkgs, ... }:
with lib;
with lib.campground;


mkStigModule {
  inherit config;
  name = "audit_package_installed";
  srgList = [ "SRG-OS-000037-GPOS-00015" ];
  stigConfig = { environment.systemPackages = [ pkgs.audit ]; };
}
