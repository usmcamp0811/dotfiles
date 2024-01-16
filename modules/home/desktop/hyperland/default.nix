{ inputs, system, options, config, lib, pkgs, ... }:

with lib;
with lib.campground;
let
  inherit (inputs) hyprland;

  cfg = config.campground.desktop.hyprland;
in
{
  options.campground.desktop.addons.hyprpaper = {
    enable = mkEnableOption "Hyprpaper";
    monitors = mkOption {
      description = "Monitors and their wallpapers";
      type = with types; listOf (submodule {
        options = {
          name = mkOption {
            type = str;
          };
          wallpaper = mkOption {
            type = path;
          };
        };
      });
    };
    wallpapers = mkOpt (types.listOf types.path) [
    ] "Wallpapers to preload.";
  };

  config =
    mkIf cfg.enable
      {
        xdg.configFile = {
          "hypr/hyprpaper.conf".text = /* bash */ ''
            # ░█░█░█▀█░█░░░█░░░█▀█░█▀█░█▀█░█▀▀░█▀▄░█▀▀
            # ░█▄█░█▀█░█░░░█░░░█▀▀░█▀█░█▀▀░█▀▀░█▀▄░▀▀█
            # ░▀░▀░▀░▀░▀▀▀░▀▀▀░▀░░░▀░▀░▀░░░▀▀▀░▀░▀░▀▀▀

            ${concatStringsSep "\n" (map (wallpaper: "preload = ${wallpaper}") cfg.wallpapers)}
            
            ${concatStringsSep "\n" (map (monitor: "wallpaper = ${monitor.name},${monitor.wallpaper}") cfg.monitors)}
            
          '';
        };

        systemd.user.services.hyprpaper = {
          Install.WantedBy = [ "hyprland-session.target" ];

          Unit = {
            Description = "Hyprpaper Service";
            PartOf = [ "graphical-session.target" ];
          };

          Service = {
            ExecStart = "${getExe pkgs.hyprpaper}";
            Restart = "always";
          };
        };
      };
}
