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
      # k9s = enabled;
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
      virtmanager = enabled; # don't forget to add to libvirtd group
    };
  };

  home.stateVersion = "23.05";
}
