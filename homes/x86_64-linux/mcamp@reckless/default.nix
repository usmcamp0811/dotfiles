{
  inputs,
  lib,
  pkgs,
  config,
  osConfig ? {},
  format ? "unknown",
  ...
}:
with lib;
with lib.fmf; {
  fmf = {
    system.xdg = enabled;
    user = {
      name = "mcamp";
      fullName = "Matt Camp";
      email = "matt@aicampground.com";
      uid = 10000;
    };
    archetypes.desktop = {
      enable = true;
      display-name = "HDMI-A-2";
    };
    desktop = {
      addons.kitty.themeFile = "Seti";
      hyprland.startup = [
        ''${pkgs.hyprland}/bin/hyprctl --instance 0 keyword monitor "keyword monitor "DP-2, disable"''
      ];
    };
    services.protonmail-bridge = enabled;
    # apps.thunderbird = enabled;
    tools.beets = enabled;
    tools.spotdl = enabled;
  };

  home.stateVersion = "23.05";
}
