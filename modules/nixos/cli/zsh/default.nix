{
  pkgs,
  lib,
  config,
  ...
}: let
  inherit (lib) mkEnableOption mkIf mkOption types;

  cfg = config.fmf.cli.zsh.root;
in {
  options.fmf.cli.zsh.root = {
    enable = mkEnableOption "ZSH for root user";
    extraSource = mkOption {
      type = with types; listOf str;
      default = [];
      description = "Additional files to source in ZSH initialization for root.";
    };
  };

  config = mkIf cfg.enable {
    # Set ZSH as root's shell (also configured in user module, but explicit here)
    users.users.root.shell = pkgs.zsh;

    # System-wide ZSH configuration
    programs.zsh = {
      enable = true;
      enableCompletion = true;
      autosuggestions.enable = true;
      syntaxHighlighting.enable = true;

      # Root user specific ZSH configuration
      interactiveShellInit = ''
        # Only apply this configuration for root user
        if [ "$USER" = "root" ]; then
          # Source fino-root theme (distinctive red theme for root)
          [ -r "/root/.config/shell/zsh/fino-root.zsh-theme" ] && source "/root/.config/shell/zsh/fino-root.zsh-theme"

          # Load fzf-tab plugin
          [ -r "${pkgs.zsh-fzf-tab}/share/fzf-tab/fzf-tab.plugin.zsh" ] && source "${pkgs.zsh-fzf-tab}/share/fzf-tab/fzf-tab.plugin.zsh"

          # Source additional files
          ${lib.concatMapStringsSep "\n"
          (file: ''[ -r "${file}" ] && source "${file}"'')
          cfg.extraSource}

          # Source vault passwords if available
          [ -r "/var/lib/vault/users/root/passwords" ] && source "/var/lib/vault/users/root/passwords"

          # Source private shell configs
          for file in /root/.config/shell/private/*.shrc(N); do
            [ -r "$file" ] && source "$file"
          done

          # Run campfetch
          ${pkgs.fmf.campfetch}/bin/campfetch

          # Enable vi mode
          bindkey -v
          bindkey '^?' backward-delete-char          # backspace in insert mode
          bindkey -M vicmd 'v' edit-command-line     # open $EDITOR in command mode

          # Useful aliases for root
          alias update='nixos-rebuild switch'
        fi
      '';
    };

    # Install fzf-tab plugin
    environment.systemPackages = with pkgs; [
      zsh-fzf-tab
      fmf.campfetch
    ];

    # Create theme files for root user
    system.activationScripts.rootZshTheme = lib.stringAfter ["users"] ''
      mkdir -p /root/.config/shell/zsh
      mkdir -p /root/.config/shell/private

      # Copy fino-root theme (root-specific with distinctive styling)
      cp ${./fino-root.zsh-theme} /root/.config/shell/zsh/fino-root.zsh-theme

      # Copy supporting theme files from the home module
      cp ${../../../home/cli/zsh/fino-theme/git.zsh} /root/.config/shell/zsh/git.zsh
      cp ${../../../home/cli/zsh/fino-theme/prompt_info_functions.zsh} /root/.config/shell/zsh/prompt_info_functions.zsh
      cp ${../../../home/cli/zsh/fino-theme/spectrum.zsh} /root/.config/shell/zsh/spectrum.zsh

      chmod 644 /root/.config/shell/zsh/*
    '';
  };
}
