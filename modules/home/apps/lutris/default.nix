{ options, config, lib, pkgs, ... }:

with lib;
with lib.campground;
let cfg = config.campground.apps.lutris;
in
{
  options.campground.apps.lutris = with types; {
    enable = mkBoolOpt false "Whether or not to enable lutris.";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      lutris
    ];
  };
}
