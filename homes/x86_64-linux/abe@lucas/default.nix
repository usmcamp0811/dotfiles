{ lib, pkgs, config, osConfig ? { }, format ? "unknown", ... }:

with lib.campground;
{
  campground = {
    user = {
      enable = true;
      name = config.snowfallorg.user.name;
    };
    tools = {
      vault = enabled;
    };

    cli = {
      zsh = enabled;
      bash = enabled;
      env = enabled;
      home-manager = enabled;
      k9s = enabled;
      broot = enabled;
      ranger = enabled;
      neovim = enabled;
      #TODO: Add my Nvim config 
    };
  };
  home.stateVersion = "23.05";
}
