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

      oh-my-zsh = {
        enable = true; # Enable Oh My Zsh
        plugins = [ "fzf" ]; # Oh My Zsh plugins
      };
      initExtra = ''
        source $HOME/.config/shell/zsh/fino.zsh-theme
        source $HOME/.config/shell/aliases.shrc
        [ -r "/var/lib/vault/users/${config.campground.user.name}/passwords" ] && source "/var/lib/vault/users/${config.campground.user.name}/passwords"
        bindkey -v
      '';
    };

    home.file = { 
      ".config/shell/zsh/fino.zsh-theme".source = ./fino-theme/fino.zsh-theme;
      ".config/shell/zsh/git.zsh".source = ./fino-theme/git.zsh;
      ".config/shell/zsh/prompt_info_functions.zsh".source = ./fino-theme/prompt_info_functions.zsh;
      ".config/shell/zsh/spectrum.zsh".source = ./fino-theme/spectrum.zsh;
    };
  };
}
