{ lib, pkgs, config, osConfig ? { }, format ? "unknown", ... }:

with lib.campground;
{
  campground = {
    user = {
      enable = true;
      name = config.snowfallorg.user.name;
      # name = "abe";
    };

    cli-apps = {
    #   zsh = enabled;
    #   neovim = enabled;
      home-manager = enabled;
    };
    #
    # tools = {
    #   git = enabled;
    #   direnv = enabled;
    # };
  };
  home.stateVersion = "23.05";
}
