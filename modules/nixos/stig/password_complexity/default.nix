{ lib, config, pkgs, ... }:
with lib;
with lib.campground;

mkStigModule {
  inherit config;
  name = "password_complexity";
  srgList = [ "SRG-OS-000266-GPOS-00101" ];
  stigConfig = {
    environment.etc."/security/pwquality.conf".text = ''
      ocredit=-1
    '';
  };
}
