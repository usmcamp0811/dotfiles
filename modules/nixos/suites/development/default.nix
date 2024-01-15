{ options, config, lib, pkgs, ... }:

with lib;
with lib.campground;
let
  cfg = config.campground.suites.development;
in
{
  options.campground.suites.development = with types; {
    enable =
      mkBoolOpt false "Whether or not to enable common development configuration.";
  };

  config = mkIf cfg.enable {
    campground = {
      tools = {
        git = enabled;
        misc = enabled;
        julia = enabled;
        python = enabled;
      };
    };
  };





}
