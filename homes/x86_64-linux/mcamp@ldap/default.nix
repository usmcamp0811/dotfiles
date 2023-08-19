{ lib, pkgs, config, osConfig ? { }, format ? "unknown", ... }:

with lib.campground;
{
  campground = {
    user = {
      enable = true;
      name = "mcamp";
    };

    cli = {
      zsh = enabled;
      bash = enabled;
      env = enabled;
      home-manager = enabled;
      k9s = enabled;
      broot = enabled;
      # neovim = enabled;
      #TODO: Add my Nvim config 
    };
    #
    apps = {
      firefox = enabled;
      brave = enabled;
      libreoffice = enabled;
      alacritty = enabled;
      kitty = enabled;
      rofi = enabled;
      mpv = enabled;
      #TODO: Add Qutebrowser
    };
    tools = {
      # git = enabled;
      direnv = enabled;
      virtmanager = enabled; # don't forget to add to libvirtd group
      julia = enabled;
      python = enabled;
    };
  };

  home.stateVersion = "23.05";
}
