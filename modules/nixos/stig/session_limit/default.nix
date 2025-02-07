{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
let cfg = config.campground.stig.session_limit;
in {
  options.campground.stig.session_limit = with types; {
    enable = mkBoolOpt false "Enable STIG Session Limit";
    justification = mkOpt (nullOr str) null "Why you didn't enable this";
  };

  config = {
    campground.stig.active.session_limit = mkIf cfg.enable {
      srg = [ "SRG-OS-000027-GPOS-00008" ];
      cci = [ "CCI-000054" ];
      config = {
        security.pam.loginLimits = [{
          domain = "*";
          item = "maxlogins";
          type = "hard";
          value = "10";
        }];
      };
    };
    assertions = [{
      assertion = !cfg.enable -> cfg.justification != null;
      message =
        "You must provide a justification if session limit enforcement is disabled.";
    }];
  };
}
