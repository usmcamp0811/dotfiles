{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
let
  cfg = config.campground.stig;

  # Define dependency relationships
  dependencies = {
    "firewall" = [
      "SRG-OS-000298-GPOS-00116"
      "SRG-OS-000096-GPOS-00050"
      "CCI-002322"
      "CCI-000382"
    ];
    "SRG-OS-000298-GPOS-00116" = [ "firewall" "CCI-002322" ];
    "SRG-OS-000096-GPOS-00050" = [ "firewall" "CCI-000382" ];
    "CCI-002322" = [ "firewall" "SRG-OS-000298-GPOS-00116" ];
    "CCI-000382" = [ "firewall" "SRG-OS-000096-GPOS-00050" ];
  };

  # Compute which STIGs are enabled based on dependencies
  propagateEnable = stig:
    any (s: cfg.${s}.enable) (dependencies.${stig} or [ ]);

in {
  options.campground.stig = with types; {
    srg.SRG-OS-000298-GPOS-00116.enable =
      mkBoolOpt false "Enable STIG SRG-OS-000298-GPOS-00116";
    srg.SRG-OS-000096-GPOS-00050.enable =
      mkBoolOpt false "Enable STIG SRG-OS-000096-GPOS-00050";
    cci.CCI-002322.enable = mkBoolOpt false "Enable STIG CCI-002322";
    cci.CCI-000382.enable = mkBoolOpt false "Enable STIG CCI-000382";
    firewall.enable = mkBoolOpt false "Enable STIG Firewall";
  };

  config = mkIf (cfg.firewall.enable || cfg.srg.SRG-OS-000298-GPOS-00116.enable
    || cfg.srg.SRG-OS-000096-GPOS-00050.enable || cfg.cci.CCI-002322.enable
    || cfg.cci.CCI-000382.enable) {
      networking.firewall.enable = mkForce true;
    };
}
