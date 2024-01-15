{ options, config, lib, pkgs, ... }:

with lib;
with lib.campground;
let 
  cfg = config.campground.desktop.addons.hyprpaper;
  inherit (pkgs.campground) wallpapers;

  hyprpaper-config = ''
  preload = ${wallpapers."hsv-saturnV.png"}
  #if more than one preload is desired then continue to preload other backgrounds
  # preload = /path/to/next_image.png
  # .. more preloads

  #set the default wallpaper(s) seen on initial workspace(s) --depending on the number of monitors used
  wallpaper = monitor1,${wallpapers."hsv-saturnV.png"}
  #if more than one monitor in use, can load a 2nd image
  # wallpaper = monitor2,/path/to/next_image.png
  # .. more monitors

  #enable splash text rendering over the wallpaper
  splash = true
  '';
in
{
  options.campground.desktop.addons.hyprpaper = with types; {
    enable = mkBoolOpt false "Whether to enable Hyprpaper in the desktop environment.";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      hyprpaper
    ];

    home.file.".config/hypr/hyprpaper.conf".source = hyprpaper-config;

  };
}

