{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
mkStigModule {
  inherit config;
  name = "session_lock";
  srgList = [ "SRG-OS-000029-GPOS-00010" ];
  cciList = [ "CCI-000057" ];
  extraConfig = {
    programs.dconf.profiles.user.databases = with lib.gvariant; [{
      settings."org/gnome/desktop/session".idle-delay = mkUint32 600;
      locks = [ "org/gnome/desktop/session/idle-delay" ];
    }];
  };
}
