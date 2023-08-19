{ lib, config, pkgs, ... }:

let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.campground.cli-apps.zsh;
in
{
  options.campground.cli-apps.zsh = {
    enable = mkEnableOption "ZSH";
      # TODO: Make initExtra accept additional options from user config
  };

  config = mkIf cfg.enable {
    programs.zsh = {
      enable = true;
      enableCompletion = true; # Enable command completion
      enableAutosuggestions = true;
      enableSyntaxHighlighting = true;

      # TODO: migrate my theme here
      oh-my-zsh = {
        enable = true; # Enable Oh My Zsh
        plugins = [ "fzf" ]; # Oh My Zsh plugins
        # theme = "fino"; # Oh My Zsh theme
        # custom = ""; # Custom Oh My Zsh configuration
      };
      # TODO: Move the passwords thing out of here
      initExtra = ''
        source $HOME/.config/shell/zsh/fino.zsh-theme
        source $HOME/.config/shell/aliases.shrc
        [ -r "/var/lib/vault/users/mcamp/passwords" ] && source "/var/lib/vault/users/mcamp/passwords"
        bindkey -v
      '';
    };

    home.file = { 
      ".config/shell/zsh/00-main.zsh".source = ./00-main.zsh;
      ".config/shell/zsh/fino.zsh-theme".source = ./fino.zsh-theme;
      ".config/shell/zsh/git.zsh".source = ./git.zsh;
      ".config/shell/zsh/prompt_info_functions.zsh".source = ./prompt_info_functions.zsh;
      ".config/shell/zsh/spectrum.zsh".source = ./spectrum.zsh;
      ".config/shell/zsh/theme-and-appearance.zsh".source = ./theme-and-appearance.zsh;
    };
  };
}
