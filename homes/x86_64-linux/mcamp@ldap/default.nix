{ lib, pkgs, config, osConfig ? { }, format ? "unknown", ... }:

with lib.campground;
{
  campground = {
    user = {
      enable = true;
      name = "mcamp";
    };

    cli-apps = {
      zsh = enabled;
      env = enabled;
      home-manager = enabled;
      # neovim = enabled;
    };
    #
    apps = {
      firefox = enabled;
      brave = enabled;
    };
    tools = {
      # git = enabled;
      direnv = enabled;
    };
  };

  home.stateVersion = "23.05";
}
