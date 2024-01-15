{ options, config, lib, pkgs, ... }:

with lib;
with lib.campground;
let cfg = config.campground.desktop.addons.hyprpaper;
in
{
  options.campground.desktop.addons.hyprpaper = with types; {
    enable = mkBoolOpt false "Whether to enable Hyprpaper in the desktop environment.";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      hyprpaper
    ];
  };
}

