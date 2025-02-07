{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
let cfg = config.campground.stig.session_lock;
in {
  options.campground.stig.session_lock = with types; {
    enable = mkBoolOpt false "Enable STIG Session Lock";
    justification = mkOpt (nullOr str) null "Why you didn't enable this";
  };

  config = {
    campground.stig.active.session_lock = mkIf cfg.enable {
      srg = [ "SRG-OS-000029-GPOS-00010" ];
      cci = [ "CCI-000057" ];
      config = {
        programs.dconf.profiles.user.databases = with lib.gvariant; [{
          settings."org/gnome/desktop/session".idle-delay = mkUint32 600;
          locks = [ "org/gnome/desktop/session/idle-delay" ];
        }];
      };
    };
    assertions = [{
      assertion = !cfg.session_lock.enable -> cfg.session_lock.justification
        != null;
      message =
        "You must provide a justification if session lock enforcement is disabled.";
    }];
  };
}
