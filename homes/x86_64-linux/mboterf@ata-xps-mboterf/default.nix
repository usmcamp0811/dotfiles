{ lib, pkgs, config, osConfig ? { }, format ? "unknown", ... }:

with lib.campground; {
  campground = {
    user = {
      enable = true;
      name = config.snowfallorg.user.name;
    };
    desktop = {
      wallpapers = enabled;
      qtile = {
        enable = true;
        wallpaper = "hsv-saturnV.png";
      };
    };

    cli = {
      zsh = enabled;
      bash = enabled;
      env = enabled;
      home-manager = enabled;
      k9s = enabled;
      broot = enabled;
      ranger = enabled;
      # neovim = enabled;
      #TODO: Add my Nvim config
    };
    services = {
      # picom = enabled;
    };

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
      git = {
        enable = true;
        userEmail = "mboterf@ata-llc.com";
        userName = "BruceBoterf";
      };
      direnv = enabled;
      # virtmanager = enabled; # don't forget to add to libvirtd group
      julia = enabled;
      python = enabled;
      vault = {
        enable = true;
        vault-addr = "http://10.2.0.215:8200";
      };
    };
  };

  home.stateVersion = "23.05";
}
