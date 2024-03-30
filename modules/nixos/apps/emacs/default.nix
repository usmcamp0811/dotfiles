{ options, config, lib, pkgs, ... }:

with lib;
with lib.campground;
let
  cfg = config.campground.apps.emacs;
  src = pkgs.fetchFromGitHub {
    owner = "syl20bnr";
    repo = "spacemacs";
    rev = "df30d9592674f71fd304091de61582f1682d506d";
    sha256 = "e/pL+9+8BRXIJr0jZ2ca5nuL5ZaJ7zJSl8DMlxyAd08=";
  };
in {
  options.campground.apps.emacs = with types; {
    enable = mkBoolOpt false "Whether or not to enable Emacs.";
    spacemacs = mkBoolOpt false "Whether or not to enable Spacemacs";
  };

  config = mkIf (cfg.enable || cfg.spacemacs) {
    environment.systemPackages = mkIf cfg.enable (with pkgs; [ emacs29 ]);

    system.activationScripts.spacemacs = lib.mkIf cfg.spacemacs {
      text = ''
        if [[ -f /home/${config.campground.user.name}/.spacemacs ]]; then
          echo "Spacemacs is already configured due to existing .spacemacs file"
        else
          echo "Initializing Spacemacs directory at /home/${config.campground.user.name}/.emacs.d"
          mkdir -p /home/${config.campground.user.name}/.emacs.d
          cp -a ${src}/. /home/${config.campground.user.name}/.emacs.d/
          chown -R ${config.campground.user.name}: /home/${config.campground.user.name}/.emacs.d
          chmod -R u+rwx /home/${config.campground.user.name}/.emacs.d/
          echo "Successfully initialized Spacemacs directory"
        fi
      '';
    };
  };
}
