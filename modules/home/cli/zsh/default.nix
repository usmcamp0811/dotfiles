{ pkgs, lib, config, ... }:
let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.campground.cli.zsh;
in
{
  options.campground.cli.zsh = {
    enable = mkEnableOption "ZSH";
    extraSource = lib.mkOption {
      # Corrected line
      type = with lib.types; listOf str;
      default = [ ];
      description = "Additional files to source in ZSH initialization.";
    };
  };

  config = mkIf cfg.enable {

    programs.zsh = {
      enable = true;
      enableCompletion = true;
      autosuggestion.enable = true;
      syntaxHighlighting.enable = true;

      shellAliases = { update = "sudo nixos-rebuild switch"; };

      oh-my-zsh = {
        enable = true;
        theme = "fino";
        plugins = [ "fzf" ];
      };
      initExtra = lib.mkBefore ''
        source $HOME/.config/shell/zsh/fino.zsh-theme
        ${lib.concatMapStringsSep "\n"
        (file: ''[ -r "${file}" ] && source "${file}"'') cfg.extraSource}
        [ -r "/var/lib/vault/users/${config.campground.user.name}/passwords" ] && source "/var/lib/vault/users/${config.campground.user.name}/passwords"
        bindkey -v

        for file in ~/.config/shell/private/*.shrc(N); do
          [ -r "$file" ] && source "$file"
        done
      '';
    };
    # TODO: Move the aliases.shrc into a nix file so if programs are called in there they are for sure installed and have the correct path
    home.file = {
      ".config/shell/zsh/fino.zsh-theme".source = ./fino-theme/fino.zsh-theme;
      ".config/shell/zsh/git.zsh".source = ./fino-theme/git.zsh;
      ".config/shell/zsh/prompt_info_functions.zsh".source =
        ./fino-theme/prompt_info_functions.zsh;
      ".config/shell/zsh/spectrum.zsh".source = ./fino-theme/spectrum.zsh;
    };
  };
}
