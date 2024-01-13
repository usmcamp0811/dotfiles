{ options, config, lib, pkgs, ... }:

with lib;
with lib.campground;

{
  options.campground.desktop.hyperland = with types; {
    enable = mkBoolOpt false "Whether or not to turn on hyperland config.";
  };

  config = mkIf cfg.enable {
    wayland.windowManager.hyprland = {
      # Whether to enable Hyprland wayland compositor
      enable = true;
      # The hyprland package to use
      package = pkgs.hyprland;
      # Whether to enable XWayland
      xwayland.enable = true;

      # Optional
      # Whether to enable hyprland-session.target on hyprland startup
      systemd.enable = true;
      # Whether to enable patching wlroots for better Nvidia support
      enableNvidiaPatches = true;
    };
  };
}
