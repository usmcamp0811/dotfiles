{ lib, config, pkgs, ... }:

let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.campground.cli-apps.zsh;
in
{
  options.campground.cli-apps.zsh = {
    enable = mkEnableOption "ZSH";
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
      initExtra = ''
        source $HOME/.config/shell/zsh/fino.zsh-theme
        source $HOME/.config/shell/aliases.shrc
        [ -r "/var/lib/vault/users/mcamp/passwords" ] && source "/var/lib/vault/users/mcamp/passwords"
        bindkey -v
      '';
    };
  };
}
