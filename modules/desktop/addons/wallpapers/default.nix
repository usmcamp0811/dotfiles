{ options, config, pkgs, lib, ... }:

with lib;
with lib.internal;
let
  cfg = config.campground.desktop.addons.wallpapers;
  inherit (pkgs.campground) wallpapers;
in
{
  options.campground.desktop.addons.wallpapers = with types; {
    enable = mkBoolOpt false
      "Whether or not to add wallpapers to ~/Pictures/wallpapers.";
  };
# TODO: Make this mine.... 
  config = {
    # campground.home.file = lib.foldl
    #   (acc: name:
    #     let wallpaper = wallpapers.${name};
    #     in
    #     acc // {
    #       "Pictures/wallpapers/${wallpaper.fileName}".source = wallpaper;
    #     })
    #   { }
    #   (wallpapers.names);
  };
}

