{ options, config, lib, pkgs, ... }:

with lib;
with lib.internal;
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
        qtile = {
          enabled = true;
          lightdm = true;
        }

        addons = { 
          wallpapers = enabled; 
          greeter = enabled;
          kitty = enabled;
          };
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
