{ options, config, lib, pkgs, ... }:

with lib;
with lib.campground;
let 
  cfg = config.campground.desktop.qtile;
in
{
  options.campground.desktop.qtile = with types; {
    enable = mkBoolOpt false "Whether or not to turn on qtile config.";
  };

  config = mkIf cfg.enable {
    home.file = { 
      ".config/qtile/config.py".source = ./config.py;
    };
  };
}

