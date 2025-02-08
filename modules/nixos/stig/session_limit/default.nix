{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
mkStigModule {
  inherit config;
  name = "session_limit";
  srgList = [ "SRG-OS-000027-GPOS-00008" ];
  cciList = [ "CCI-000054" ];
  extraConfig = {
    security.pam.loginLimits = [{
      domain = "*";
      item = "maxlogins";
      type = "hard";
      value = "10";
    }];
  };
}
