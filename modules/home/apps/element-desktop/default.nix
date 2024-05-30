{
  options,
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.campground; let
  cfg = config.campground.apps.element-desktop;
in {
  options.campground.apps.element-desktop = with types; {
    enable =
      mkBoolOpt false "Whether or not to enable Mattermost Desktop Client.";
    isWayland =
      mkBoolOpt config.campground.desktop.hyprland.enable
      "Insall wayland version";
  };

  config = mkIf cfg.enable {
    home.packages =
      lib.optional (!cfg.isWayland) pkgs.element-desktop
      ++ lib.optional cfg.isWayland pkgs.element-desktop-wayland;
  };
}
