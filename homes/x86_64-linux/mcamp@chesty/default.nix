{ lib, pkgs, config, osConfig ? { }, format ? "unknown", ... }:

with lib.campground; {
  campground = {
    user = {
      enable = true;
      name = config.snowfallorg.user.name;
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
    };
    services = {
      openssh = enabled;
      syncthing = enabled;
    };

    tools = {
      git = enabled;
      direnv = enabled;
      vault = enabled;
    };
  };
  home.stateVersion = "23.05";
}
