{ options, config, lib, pkgs, ... }:

with lib;
with lib.campground;
let
  cfg = config.campground.apps.slack;
in
{
  options.campground.apps.slack = with types; {
    enable = mkBoolOpt false "Whether or not to enable Slack Desktop Client.";
  };

  config = mkIf cfg.enable {

    home.packages = with pkgs; [
      slack
    ];

  };

}

