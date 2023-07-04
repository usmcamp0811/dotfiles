{ config, pkgs, ... }:

{
  home.username = "mcamp";
  home.homeDirectory = "/home/mcamp";
  home.stateVersion = "23.05"; # Please read the comment before changing.

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
    tldr
    zathura
    bat
    lazygit
    yt-dlp
    hello
    pipewire
    pavucontrol
    xdg-desktop-portal
    rofi
    brave
    firefox
    # qutebrowser
    kitty
    noto-fonts
    noto-fonts-emoji
    fira-mono
    dejavu_fonts
    fira-code-symbols
    nerdfonts
    hack-font
    font-awesome
    ibm-plex
    material-design-icons
    networkmanager
    networkmanagerapplet
  ];

  home.sessionVariables = {
    EDITOR = "nvim";
  };

  # services.pipewire = {
    # enable = true;
    # alsa.enable = true;
    # alsa.support32Bit = true;
    # pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;
  # };
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
}

