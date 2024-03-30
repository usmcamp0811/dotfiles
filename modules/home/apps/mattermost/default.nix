{ options, config, lib, pkgs, ... }:

with lib;
with lib.campground;
let cfg = config.campground.apps.mattermost-desktop;
in {
  options.campground.apps.mattermost-desktop = with types; {
    enable =
      mkBoolOpt false "Whether or not to enable Mattermost Desktop Client.";
  };

  config = mkIf cfg.enable {

    home.packages = with pkgs; [ mattermost-desktop ];

  };

}

