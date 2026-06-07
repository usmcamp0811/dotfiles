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

      events = {
        before-sleep = "${getExe config.programs.swaylock.package} -defF";
        after-resume = "${
          getExe' config.wayland.windowManager.hyprland.package "hyprctl"
        } dispatch dpms on";
        lock = "${getExe config.programs.swaylock.package} -defF";
      };
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
