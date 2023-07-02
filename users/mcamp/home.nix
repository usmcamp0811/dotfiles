{ config, pkgs, ... }:
let
  this_user = import ./user.nix;
in
{
  home.packages = with pkgs; [
    lua
    zig
    deno
    neovim
    lsd
    ranger
    git
    tmux
    ansible
    xsel
    zathura
    bat
    lazygit
    yt-dlp
    lightdm
    qtile
    git-crypt
    gnupg
    emacs
    bitwarden
    bitwarden-cli
    rnix-lsp 
    cargo

  ];

  home.sessionVariables = {
    EDITOR = "nvim";
  };

  programs.home-manager.enable = true;
  programs.bat = {
    enable = true;
    config = {
      theme = "TwoDark";
      italic-text = "always";
    };
  };

  programs.bash = {
    enable = true;
    initExtra = ''
      source ${config.home.homeDirectory}/.config/shell/aliases.shrc
    '';
  };
  
  programs.zsh = {
    enable = true;
    initExtra = ''
      for file in ${config.home.homeDirectory}/.config/shell/zsh/*.zsh; do
          [ -r "$file" ] && source "$file"
      done

      # source all the other bash config files
      for file in ${config.home.homeDirectory}/.config/shell/*.shrc; do
          [ -r "$file" ] && source "$file"
      done

      for file in ${config.home.homeDirectory}/.config/shell/private/*.shrc; do
          [ -r "$file" ] && source "$file"
      done

      source ${config.home.homeDirectory}/.config/shell/zsh/theme

    '';
  };
  programs.neovim = {
    viAlias = true;
    vimAlias = true;
  };

}

