{ inputs, options, config, lib, pkgs, ... }:

with lib;
with lib.campground;
let 
  cfg = config.campground.desktop.addons.swayidle;
  inherit (inputs) nixpkgs-wayland;
in
{
  options.campground.desktop.addons.swayidle = with types; {
    enable =
      mkBoolOpt false "Whether to enable swayidle in the desktop environment.";
  };
  config = mkIf cfg.enable {
    services.swayidle = {
      enable = true;
      package = nixpkgs-wayland.packages.${system}.swayidle;

      events = [
        {
          event = "before-sleep";
          command = "${getExe config.programs.swaylock.package} -defF";
        }
        {
          # TODO: Make dynamic for window manager
          event = "after-resume";
          command = "${getExe' config.wayland.windowManager.hyprland.package "hyprctl"} dispatch dpms on";
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
          # TODO: Make dynamic for window manager
          timeout = 1200;
          command = "${getExe' config.wayland.windowManager.hyprland.package "hyprctl"} dispatch dpms off";
        }
      ];
    };
  };
}

