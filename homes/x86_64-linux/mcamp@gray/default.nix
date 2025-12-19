{ inputs, lib, pkgs, config, osConfig ? { }, format ? "unknown", ... }:
with lib;
with lib.fmf; {
  fmf = {
    user = {
      name = "mcamp";
      fullName = "Matt Camp";
      email = "matt@aicampground.com";
      uid = 10000;
    };
    archetypes.desktop = {
      enable = true;
      display-name = "eDP-1";
    };
  };

  home.stateVersion = "23.05";
}
