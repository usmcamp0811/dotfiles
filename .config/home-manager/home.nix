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
    neovim
    lsd
    ranger
    git
    tmux
    ansible
    xsel
    zathura
    bat
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
      theme = "GitHub";
      italic-text = "always";
    };
  };

  programs.bash = {
    enable = true;
    shellAliases = {
      ".." = "cd ..";
      "..." = "cd ../..";
      "...." = "cd ../../..";
      "....." = "cd ../../../..";
      "~" = "cd ~";
      "-" = "cd -";
      "ranger" = ''ranger --choosedir=$HOME/.rangerdir; LASTDIR=`cat $HOME/.rangerdir`; cd "$LASTDIR"'';
      "mv" = "mv -v";
      "rm" = "rm -i -v";
      "cp" = "cp -v";
      "chmox" = "chmod -x";
      "vim" = "nvim";
      "df" = "df -h";
      "gs" = "git status";
      "undopush" = "git push -f origin HEAD^:master";
      "gr" = "bash -c '[ ! -z $(git rev-parse --show-cdup) ] && cd $(git rev-parse --show-cdup || pwd)'";
      "master" = "git checkout master";
      "fix-pacman" = "sudo rm /var/lib/pacman/db.lck";
      "dotfiles" = "git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME";
      "lazydot" = "lazygit --git-dir=$HOME/.dotfiles/ --work-tree=$HOME";
      "i3config" = "nvim ~/.config/i3/config";
      "qconfig" = "vim ~/.config/qtile/config.py";
      "aliases" = "nvim ~/.config/shell/aliases.shrc";
      "exports" = "nvim ~/.config/shell/exports.shrc";
      "vplug" = "nvim ~/.config/nvim/load_plugins.vim";
      "vplug2" = "nvim ~/.config/nvim/config_plugins.vim";
      "vkeys" = "nvim ~/.config/nvim/key-mappings.vim";
      "vgen" = "nvim ~/.config/nvim/general.vim";
      "vinit" = "nvim ~/.config/nvim/init.vim";
    };
  };
  
  programs.zsh = {
    enable = true;
    shellAliases = {
      ".." = "cd ..";
      "..." = "cd ../..";
      "...." = "cd ../../..";
      "....." = "cd ../../../..";
      "~" = "cd ~";
      "-" = "cd -";
      "ranger" = ''ranger --choosedir=$HOME/.rangerdir; LASTDIR=`cat $HOME/.rangerdir`; cd "$LASTDIR"'';
      "mv" = "mv -v";
      "rm" = "rm -i -v";
      "cp" = "cp -v";
      "chmox" = "chmod -x";
      "vim" = "nvim";
      "df" = "df -h";
      "gs" = "git status";
      "undopush" = "git push -f origin HEAD^:master";
      "gr" = "bash -c '[ ! -z $(git rev-parse --show-cdup) ] && cd $(git rev-parse --show-cdup || pwd)'";
      "master" = "git checkout master";
      "fix-pacman" = "sudo rm /var/lib/pacman/db.lck";
      "dotfiles" = "git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME";
      "lazydot" = "lazygit --git-dir=$HOME/.dotfiles/ --work-tree=$HOME";
      "i3config" = "nvim ~/.config/i3/config";
      "qconfig" = "vim ~/.config/qtile/config.py";
      "aliases" = "nvim ~/.config/shell/aliases.shrc";
      "exports" = "nvim ~/.config/shell/exports.shrc";
      "vplug" = "nvim ~/.config/nvim/load_plugins.vim";
      "vplug2" = "nvim ~/.config/nvim/config_plugins.vim";
      "vkeys" = "nvim ~/.config/nvim/key-mappings.vim";
      "vgen" = "nvim ~/.config/nvim/general.vim";
      "vinit" = "nvim ~/.config/nvim/init.vim";
    };
  };
}

