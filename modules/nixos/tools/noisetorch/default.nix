{ options, config, lib, pkgs, ... }:

with lib;
with lib.campground;
let cfg = config.campground.tools.noisetorch;
in {
  options.campground.tools.noisetorch = with types; {
    enable = mkBoolOpt false "Whether or not to enable noisetorch.";
  };

  config = mkIf cfg.enable { programs.noisetorch.enable = true; };
}
