{ lib
, config
, ...
}:
let
  cfg = config.fmf.cli.bash;
in
{
  options.fmf.cli.bash = {
    enable = lib.mkEnableOption "Bash";
    extraSource = lib.mkOption {
      type = with lib.types; listOf str;
      default = [ ];
      description = "Additional files to source in Bash initialization.";
    };
  };

  # TODO: Maybe setup powerline-shell or some other PS1 prompt
  config = lib.mkIf cfg.enable {
    home.file.".bashrc".text = ''
      # Custom prompt
      PS1='\u@\h:\w\$ '

      # Enable Vim mode
      set -o vi

      # Aliases
      alias ls="ls --color=auto"
      alias ll="ls -l"

      # Source extra files
      ${lib.concatMapStringsSep "\n"
        (file: ''[ -r "${file}" ] && source "${file}"'')
        cfg.extraSource}
      source $HOME/.config/shell/aliases.shrc
      [ -r "/var/lib/vault/users/${config.fmf.user.name}/passwords" ] && source "/var/lib/vault/users/${config.fmf.user.name}/passwords"
    '';
  };
}
