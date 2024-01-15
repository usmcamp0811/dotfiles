{ options, config, lib, pkgs, ... }:

with lib;
with lib.campground;
let
  cfg = config.campground.suites.programming;
in
{
  options.campground.suites.programming = with types; {
    enable =
      mkBoolOpt false "Whether or not to enable common programming configuration.";
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
