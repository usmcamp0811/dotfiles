{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
let cfg = config.campground.stig.session_limit;
in {
  options.campground.stig.session_limit = with types; {
    enable = mkBoolOpt false "Enable STIG Session Limit";
    justification = mkOpt (nullOr str) null "Why you didn't enable this";
  };

  config = mkIf cfg.enable {
    campground.stig.srg = [ "SRG-OS-000027-GPOS-00008" ];
    campground.stig.cci = [ "CCI-000054" ];

    security.pam.loginLimits = [{
      domain = "*";
      item = "maxlogins";
      type = "hard";
      value = "10";
    }];
  };
}
