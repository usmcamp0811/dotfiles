{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
let cfg = config.campground.stig;
in {
  options.campground.stig = with types; {
    enable = mkBoolOpt false "Stig the machine";
    srg = mkOpt (listOf str) [ ] "SRGs that are enabled";
    cci = mkOpt (listOf str) [ ] "CCIs that are enabled";
  };
  config = mkIf cfg.enable {
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
        assertion = !cfg.login_attempts.enable
          -> cfg.login_attempts.justification != null;
        message =
          "You must provide a justification if login attempt restrictions are disabled.";
      }
      {
        assertion = !cfg.banner.enable -> cfg.banner.justification != null;
        message =
          "You must provide a justification if the graphical login banner is disabled.";
      }
      {
        assertion = !cfg.session_limit.enable -> cfg.session_limit.justification
          != null;
        message =
          "You must provide a justification if session limit enforcement is disabled.";
      }
      {
        assertion = !cfg.session_lock.enable -> cfg.session_lock.justification
          != null;
        message =
          "You must provide a justification if session lock enforcement is disabled.";
      }
    ];
  };
}
