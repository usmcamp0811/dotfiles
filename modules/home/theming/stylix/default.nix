{
  options,
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.fmf; {
  # Disable stylix waybar theming when waybar module is enabled
  # This allows our custom waybar styles to be used instead
  config = mkIf (config.fmf.desktop.addons.waybar.enable or false) {
    # stylix.targets.waybar.enable = mkForce false;
  };
}
