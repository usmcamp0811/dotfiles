{ options, config, lib, pkgs, ... }:

with lib;
with lib.campground;
let
  cfg = config.campground.suites.desktop;
in
{
  options.campground.suites.desktop = with types; {
    enable =
      mkBoolOpt false "Whether or not to enable common desktop configuration.";
  };

  config = mkIf cfg.enable {
    campground = {
      desktop = {
        addons = { 
          wallpapers = enabled; 
          greeter = enabled;
          kitty = enabled;
        };
        display-manager = {
          gdm = {
            enable = true;
            wayland = true;
          };
        };
        # qtile = enabled;
        hyprland = enabled;
      };
      apps = {
        # _1password = enabled;
        # firefox = enabled;
        # vlc = enabled;
        # logseq = enabled;
        # hey = enabled;
        # pocketcasts = enabled;
        # yt-music = enabled;
        # twitter = enabled;
        # gparted = enabled;
      };
    };
  };





}
