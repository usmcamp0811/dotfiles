{ options
, config
, lib
, pkgs
, ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.desktop.addons.swayidle;
  # inherit (inputs) nixpkgs-wayland;
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

      events = [
        {
          event = "before-sleep";
          command = "${getExe config.programs.swaylock.package} -defF";
        }
        {
          event = "after-resume";
          command = "${
            getExe' config.wayland.windowManager.hyprland.package "hyprctl"
          } dispatch dpms on";
        }
        {
          event = "lock";
          command = "${getExe config.programs.swaylock.package} -defF";
        }
      ];
      timeouts = [
        {
          timeout = 900;
          command = "${getExe config.programs.swaylock.package} -defF";
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
