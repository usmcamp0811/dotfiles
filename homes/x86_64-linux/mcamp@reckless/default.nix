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
with lib.campground; {
  campground = {
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
    desktop.hyprland.startup = [
      ''
        local sig
        sig=$(${pkgs.hyprland}/bin/hpyrctl  instances | ${pkgs.gawk}/bin/awk '/^instance /{gsub(":","",$2); print $2; exit}')
        ${pkgs.hyprland}/bin/hpyrctl --instance "$sig" keyword monitor "DP-2, disable"
      ''
    ];
    services.protonmail-bridge = enabled;
    # apps.thunderbird = enabled;
    tools.beets = enabled;
    tools.spotdl = enabled;
  };

  home.stateVersion = "23.05";
}
