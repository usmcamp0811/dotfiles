{ lib, config, pkgs, ... }:

let
  cfg = config.campground.cli-apps.bash;
in
{
  options.campground.cli-apps.bash = {
    enable = lib.mkEnableOption "Bash";
    extraSource = lib.mkOption {
      type = with lib.types; listOf str;
      default = [];
      description = "Additional files to source in Bash initialization.";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.bash = {
      enable = true;

      # Bash Prompt Configuration
      promptInit = ''
        PS1='\u@\h:\w\$ '
      '';

      # Bashrc Content
      bashrcExtra = ''
        # Enable Vim mode
        set -o vi

        # Source extra files
        ${lib.concatMapStringsSep "\n" (file: "[ -r \"${file}\" ] && source \"${file}\"") cfg.extraSource}

        source $HOME/.config/shell/aliases.shrc
        [ -r "/var/lib/vault/users/${config.campground.user.name}/passwords" ] && source "/var/lib/vault/users/${config.campground.user.name}/passwords"
      '';
    };
  };
}
