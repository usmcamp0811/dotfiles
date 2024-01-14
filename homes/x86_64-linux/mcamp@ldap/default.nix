{ inputs, lib, pkgs, config, osConfig ? { }, format ? "unknown", ... }:

with lib.campground;
{

  # imports = [ 
  #   inputs.scientific-fhs.nixosModules.default
  # ];

  campground = {
    user = {
      enable = true;
      name = "mcamp";
      fullName = "Matt Camp";
      email = "matt@aicampground.com";
    };
    desktop = {
      addons.gbar = enabled;
      wallpapers = enabled;
      qtile = {
        enable = true;
        wallpaper = "hsv-saturnV.png";
      };
      hyprland = enabled;
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
    services = {
      # picom = enabled;
      openssh = enabled;
      syncthing = enabled;
    };

    apps = {
      barrier = enabled;
      firefox = enabled;
      brave = enabled;
      libreoffice = enabled;
      alacritty = enabled;
      kitty = enabled;
      rofi = enabled;
      mpv = enabled;
      zoom = enabled;
      qutebrowser = enabled;
      ckb-next = enabled;
      #TODO: Add Qutebrowser
    };
    tools = {
      git = enabled;
      vault = enabled;
      direnv = enabled;
      virtmanager = enabled; # don't forget to add to libvirtd group
      julia = enabled;
      jupyter = enabled;
      python = enabled;
      emoji-picker = enabled;
      scientific-fhs = enabled;
      # dvc = enabled;
    };
  };

  home.stateVersion = "23.05";
}
