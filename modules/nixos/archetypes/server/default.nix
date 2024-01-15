{ options, config, lib, pkgs, ... }:
with lib;
with lib.campground;
let cfg = config.campground.archetypes.server;
in
{
  options.campground.archetypes.server = with types; {
    enable =
      mkBoolOpt false "Whether or not to enable the server archetype.";
  };

  config = mkIf cfg.enable {
    campground = {
      suites = {
        common = enabled;
      };
    };
  };
}
