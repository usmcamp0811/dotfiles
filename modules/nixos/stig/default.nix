{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
let cfg = config.campground.stig;
in {
  options.campground.stig = with types; {
    srg = mkOpt (listOf str) [ ] "SRGs that are enabled";
    cci = mkOpt (listOf str) [ ] "CCIs that are enabled";
  };
  config = {
    assertions = [
      {
        assertion = !cfg.firewall.enable -> cfg.firewall.justification != null;
        message =
          "You must provide a justification if the firewall is disabled.";
      }
      {
        assertion = !cfg.account_expiry.enable -> cfg.justification != null;
        message =
          "You must provide a justification if account expiration enforcement is disabled.";
      }
    ];
  };
}
