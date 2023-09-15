{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
let
  cfg = config.campground.services.getty;
in
{
  options.campground.services.getty = with types; {
    enable = mkBoolOpt false "Enable Getty;";
  };

  config = mkIf cfg.enable {
    systemd.services.customGetty = {
      description = "Custom Getty";
      after = [ "systemd-user-sessions.service" ];
      wantedBy = [ "multi-user.target" ];
      
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.agetty}/sbin/agetty --autologin ${config.campground.user.name} --noclear tty2 38400 linux";
        Restart = "always";
        UMask = "0022";
        TTYPath = "/dev/tty2";
        TTYReset = "yes";
      };
    };
  };
}


