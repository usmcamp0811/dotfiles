{ inputs, system, options, config, lib, pkgs, ... }:

with lib;
with lib.campground;
let
  inherit (inputs) hyprland;

  cfg = config.campground.desktop.hyprland;
in
{
  options.campground.desktop.hyprland = with types; {
    enable = mkBoolOpt false "Whether or not to turn on hyperland config.";
    appendConfig = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = ''
        Extra configuration lines to add to bottom of `~/.config/hypr/hyprland.conf`.
      '';
    };
    prependConfig = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = ''
        Extra configuration lines to add to top of `~/.config/hypr/hyprland.conf`.
      '';
    };
  };

  imports = [
    ./binds.nix
  ];

  config = mkIf cfg.enable {
    programs.waybar = { 
      enable = true;
      systemd.target = "hyprland-session.target";
    };


    wayland.windowManager.hyprland = {
      enable = true;
      extraConfig = /* bash */ ''
        ${cfg.prependConfig}
        env = XDG_DATA_DIRS,'${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}':$XDG_DATA_DIRS
        env = HYPRLAND_TRACE,1
        ${cfg.appendConfig}
      '';
      package = hyprland.packages.${system}.hyprland;

      systemd = {
        enable = true;
      };
      xwayland.enable = true;
    };
  };
}
