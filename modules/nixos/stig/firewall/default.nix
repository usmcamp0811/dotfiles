{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
let cfg = config.campground.stig.firewall;
in {
  options.campground.stig.firewall = with types; {
    enable = mkBoolOpt false "Enable STIG Firewall";
    justification = mkOpt (nullOr str) null "Why you didn't enable this";
  };

  config = {
    campground.stig.active.firewall = mkIf cfg.enable {
      srg = [ "SRG-OS-000298-GPOS-00116" "SRG-OS-000096-GPOS-00050" ];
      cci = [ "CCI-002322" "CCI-000382" ];
      config = { networking.firewall.enable = mkForce true; };
    };
    assertions = [{
      assertion = !cfg.enable -> cfg.justification != null;
      message = "You must provide a justification if the firewall is disabled.";
    }];
  };
}
