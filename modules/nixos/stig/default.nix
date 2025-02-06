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
        assertion = !cfg.account_expiry.enable
          -> cfg.account_expiry.justification != null;
        message =
          "You must provide a justification if account expiration enforcement is disabled.";
      }
      {
        assertion = !cfg.audit.enable -> cfg.audit.justification != null;
        message =
          "You must provide a justification if audit enforcement is disabled.";
      }
      {
        assertion = !cfg.login_attempts.enable -> cfg.justification != null;
        message =
          "You must provide a justification if login attempt restrictions are disabled.";
      }
    ];
  };
}
