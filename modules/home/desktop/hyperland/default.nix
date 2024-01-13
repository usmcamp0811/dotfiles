{ options, config, lib, pkgs, ... }:

with lib;
with lib.campground;
let
  cfg = config.campground.desktop.hyperland;
in
{
  options.campground.desktop.hyperland = with types; {
    enable = mkBoolOpt false "Whether or not to turn on hyperland config.";
  };

  config = mkIf cfg.enable {
    wayland.windowManager.hyprland = {
      enable = true;
      extraConfig = /* bash */ ''
        ${cfg.prependConfig}
        env = XDG_DATA_DIRS,'${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}':$XDG_DATA_DIRS
        env = HYPRLAND_TRACE,1
        ${cfg.appendConfig}
      '';
      package = hyprland.packages.${system}.hyprland;
      settings = {
        exec = [
          "${getExe pkgs.libnotify} --icon ~/.face -u normal \"Hello $(whoami)\""
        ];
      };
      systemd = {
        enable = true;
      };
      xwayland.enable = true;
    };
    # wayland.windowManager.hyprland = {
    #   # Whether to enable Hyprland wayland compositor
    #   enable = true;
    #   # The hyprland package to use
    #   package = pkgs.hyprland;
    #   # Whether to enable XWayland
    #   xwayland.enable = true;
    #
    #   # Optional
    #   # Whether to enable hyprland-session.target on hyprland startup
    #   systemd.enable = true;
    #   # Whether to enable patching wlroots for better Nvidia support
    #   enableNvidiaPatches = true;
    # };
  };
}
