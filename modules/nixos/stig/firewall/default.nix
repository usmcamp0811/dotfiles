{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
mkStigModule {
  inherit config;
  name = "firewall";
  srgList = [ "SRG-OS-000298-GPOS-00116" "SRG-OS-000096-GPOS-00050" ];
  cciList = [ "CCI-002322" "CCI-000382" ];
  extraConfig = { networking.firewall.enable = mkForce true; };
}
