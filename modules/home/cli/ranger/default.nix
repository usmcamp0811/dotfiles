{ options, config, pkgs, lib, ... }:
with lib;
with lib.campground;
let cfg = config.campground.cli.ranger;
in {
  options.campground.cli.ranger = { enable = mkEnableOption "Ranger"; };

  config = mkIf cfg.enable {
    campground.cli.aliases = {

      lr = "ranger";
      ranger = ''
        ${pkgs.ranger}/bin/ranger --choosedir=$HOME/.rangerdir; LASTDIR=`cat $HOME/.rangerdir`; cd "$LASTDIR"
      '';

    };
    home.packages = with pkgs; [ ranger ueberzug ];
    # TODO: Look at moving some of the shell sripts into Nix Shell Scripts
    # TODO: Make Kitty and ueberzug options for how to display images. Maybe set ueberzug if Alacitty is true
    home.file = {
      ".config/ranger/rc.conf" = { source = ./configs/rc.conf; };
      ".config/ranger/rifle.conf" = { source = ./configs/rifle.conf; };
      ".config/ranger/devicons.py" = { source = ./configs/devicons.py; };
      ".config/ranger/scope.sh" = { source = ./configs/scope.sh; };
      ".config/ranger/plugins/__init__.py" = {
        source = ./configs/plugins/__init__.py;
      };
      ".config/ranger/plugins/devicons_linemode.py" = {
        source = ./configs/plugins/devicons_linemode.py;
      };
    };
  };
}
