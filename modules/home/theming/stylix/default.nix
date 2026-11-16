{
  options,
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.fmf; {
  config = mkMerge [
    (optionalAttrs (hasAttrByPath [ "stylix" "enableReleaseChecks" ] options) {
      stylix.enableReleaseChecks = false;
    })
    # Home Manager (stateVersion < 26.05) warns when gtk.gtk4.theme is left on its legacy default
    # (config.gtk.theme), which is the case whenever Stylix enables gtk but fmf's gtk addon is off.
    # State that default explicitly: same behavior, no warning. fmf.desktop.addons.gtk sets its own value.
    (optionalAttrs (hasAttrByPath [ "gtk" "gtk4" "theme" ] options) {
      gtk.gtk4.theme = mkDefault config.gtk.theme;
    })
    (mkIf (config.fmf.desktop.addons.waybar.enable or false) {
      # stylix.targets.waybar.enable = mkForce false;
    })
  ];
}
