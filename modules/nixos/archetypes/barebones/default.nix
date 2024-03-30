{ options, config, lib, pkgs, ... }:
with lib;
with lib.campground;
let cfg = config.campground.archetypes.barebones;
in {
  options.campground.archetypes.barebones = with types; {
    enable =
      mkBoolOpt false "Whether or not to enable the barebones archetype.";
  };

  config =
    mkIf cfg.enable { campground = { suites = { common = enabled; }; }; };
}
