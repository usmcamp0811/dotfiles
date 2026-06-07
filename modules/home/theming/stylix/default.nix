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
    (mkIf (config.fmf.desktop.addons.waybar.enable or false) {
      # stylix.targets.waybar.enable = mkForce false;
    })
  ];
}
