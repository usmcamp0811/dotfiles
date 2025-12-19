{ lib, pkgs, config, osConfig ? { }, format ? "unknown", ... }:
with lib.fmf; {
  fmf = {
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
