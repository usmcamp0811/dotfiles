{ pkgs, plusultra, ... }:

{
  programs.home-manager.enable = true;

  # Enable the GIMP module
#  plusultra.apps.gimp.enable = true;

  # Set your shell
  programs.zsh.enable = true;

  # Set your editor
  programs.neovim.enable = true;

  # Define some aliases
  home.sessionVariables = {
    ll = "ls -l";
    la = "ls -A";
  };

  # Define your packages
  home.packages = with pkgs; [
    k9s
    btop
    julia
    deno
    autorandr
    arandr
    feh
    qutebrowser
    zathura
    dunst
    go-sct
  ];
}

