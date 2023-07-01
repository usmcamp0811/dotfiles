{ config, pkgs, ... }:

{
  # Home Manager needs a bit of information about you and the paths it should
  # manage.
  home.username = "mcamp";
  home.homeDirectory = "/home/mcamp";

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  #
  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.
  home.stateVersion = "23.05"; # Please read the comment before changing.

  # The home.packages option allows you to install Nix packages into your
  # environment.
  home.packages = with pkgs; [
    gcc
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

  ];

  # home.file.".config/ranger/commands.py".source = ./ranger-commands.py;

  # You can also manage environment variables but you will have to manually
  # source
  #
  #  ~/.nix-profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  /etc/profiles/per-user/mcamp/etc/profile.d/hm-session-vars.sh
  #
  # if you don't want to manage your shell through Home Manager.
  home.sessionVariables = {
    EDITOR = "nvim";
  };

  # Let Home Manager install and manage itself.
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

