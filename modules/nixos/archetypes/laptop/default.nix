{ options, config, lib, pkgs, ... }:
with lib;
with lib.campground;
let cfg = config.campground.archetypes.laptop;
in
{
  options.campground.archetypes.laptop = with types; {
    enable =
      mkBoolOpt false "Whether or not to enable the laptop archetype.";
  };

  config = mkIf cfg.enable {
    campground = {
      suites = {
        common = enabled;
        desktop = enabled;
        development = enabled;
      };
    };
  };
}
