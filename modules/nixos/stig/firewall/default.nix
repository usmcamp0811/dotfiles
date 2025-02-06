{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
let cfg = config.campground.stig.firewall;
in {
  options.campground.stig.firewall = with types; {
    enable = mkBoolOpt false "Enable STIG Firewall";
    justification = mkOpt (nullOr str) null "Why you didn't enable this";
  };

  config = mkIf cfg.enable {
    campground.stig.srg =
      [ "SRG-OS-000298-GPOS-00116" "SRG-OS-000096-GPOS-00050" ];
    campground.stig.cci = [ "CCI-002322" "CCI-000382" ];
    networking.firewall.enable = mkForce true;
  };
}
