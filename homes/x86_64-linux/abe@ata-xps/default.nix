{ lib, pkgs, config, osConfig ? { }, format ? "unknown", ... }:
with lib.campground; {
  campground = {
    user = {
      enable = true;
      name = "abe";
    };

    cli = {
      zsh = enabled;
      home-manager = enabled;
    };
  };
  home.stateVersion = "23.05";
}
