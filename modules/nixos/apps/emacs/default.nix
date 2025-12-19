{
  options,
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.apps.emacs;
  src = pkgs.fetchFromGitHub {
    owner = "syl20bnr";
    repo = "spacemacs";
    rev = "df30d9592674f71fd304091de61582f1682d506d";
    sha256 = "e/pL+9+8BRXIJr0jZ2ca5nuL5ZaJ7zJSl8DMlxyAd08=";
  };
in {
  options.fmf.apps.emacs = with types; {
    enable = mkBoolOpt false "Whether or not to enable Emacs.";
    spacemacs = mkBoolOpt false "Whether or not to enable Spacemacs";
  };

  config = mkIf (cfg.enable || cfg.spacemacs) {
    environment.systemPackages = mkIf cfg.enable (with pkgs; [emacs29]);

    system.activationScripts.spacemacs = lib.mkIf cfg.spacemacs {
      text = ''
        if [[ -f /home/${config.fmf.user.name}/.spacemacs ]]; then
          echo "Spacemacs is already configured due to existing .spacemacs file"
        else
          echo "Initializing Spacemacs directory at /home/${config.fmf.user.name}/.emacs.d"
          mkdir -p /home/${config.fmf.user.name}/.emacs.d
          cp -a ${src}/. /home/${config.fmf.user.name}/.emacs.d/
          chown -R ${config.fmf.user.name}: /home/${config.fmf.user.name}/.emacs.d
          chmod -R u+rwx /home/${config.fmf.user.name}/.emacs.d/
          echo "Successfully initialized Spacemacs directory"
        fi
      '';
    };
  };
}
