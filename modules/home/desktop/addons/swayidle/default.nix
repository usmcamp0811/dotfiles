{ options
, config
, lib
, pkgs
, ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.desktop.addons.swayidle;
  swaylockCfg = config.fmf.desktop.addons.swaylock;
  
  # Use video-lock if enabled, otherwise use regular swaylock
  lockCommand = if swaylockCfg.useVideoBackground
    then "${pkgs.writeShellScript "lock" ''exec video-lock''}"
    else "${getExe config.programs.swaylock.package} -defF";
in
{
  options.fmf.desktop.addons.swayidle = with types; {
    enable =
      mkBoolOpt false "Whether to enable swayidle in the desktop environment.";
  };
  config = mkIf cfg.enable {
    services.swayidle = {
      enable = true;
      package = pkgs.swayidle;

      events = {
        before-sleep = lockCommand;
        after-resume = "${
          getExe' config.wayland.windowManager.hyprland.package "hyprctl"
        } dispatch dpms on";
        lock = lockCommand;
      };
      timeouts = [
        {
          timeout = 900;
          command = lockCommand;
        }
        {
          timeout = 1200;
          command = "${
            getExe' config.wayland.windowManager.hyprland.package "hyprctl"
          } dispatch dpms off";
        }
      ];
    };
  };
}
