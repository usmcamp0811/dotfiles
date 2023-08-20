{ options, config, lib, pkgs, ... }:

with lib;
with lib.campground;
let 
  cfg = config.campground.desktop.qtile;
in
{
  options.campground.desktop.qtile = with types; {
    enable = mkBoolOpt false "Whether or not to turn on qtile config.";
    wallpaper = mkOpt str "hsv-saturnV.png" "Name of the Wallpaper to Set";
  };

  config = mkIf cfg.enable {
    home.file = { 
      ".config/qtile/config.py".source = ./config.py;
      ".config/qtile/autostart.sh".text = ''
#!/bin/sh

${pkgs.redshift}/bin/redshift-gtk -l 34.6503:86.7757 -t 5700:3600 -g 0.8 -m randr -v &
${pkgs.xautolock}/bin/xautolock -time 10 -locker i3lock-fancy &
${pkgs.feh}/bin/feh --bg-scale $HOME/Pictures/wallpaper/${cfg.wallpaper}
      '';
    };
  };
}

