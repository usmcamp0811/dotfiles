{ inputs, lib, pkgs, config, osConfig ? { }, format ? "unknown", ... }:
with lib;
with lib.campground; {
  campground = {
    user = {
      name = "mcamp";
      fullName = "Matt Camp";
      email = "matt@aicampground.com";
      uid = 10000;
    };
    archetypes.desktop = enabled;
  };

  home.stateVersion = "23.05";
}
