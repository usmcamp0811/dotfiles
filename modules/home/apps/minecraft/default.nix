{ options, config, lib, pkgs, ... }:

with lib;
with lib.campground;
let cfg = config.campground.apps.minecraft;
in
{
  options.campground.apps.minecraft = with types; {
    enable = mkBoolOpt false "Whether or not to enable minecraft.";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      minecraft
    ];
  };
}
