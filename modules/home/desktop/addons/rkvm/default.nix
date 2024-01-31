{ inputs, options, config, lib, pkgs, ... }:

with lib;
with lib.campground;
let 
  cfg = config.campground.desktop.addons.rkvm;
in
{
  options.campground.desktop.addons.rkvm = with types; {
    enable =
      mkBoolOpt false "Whether to enable rkvm in the desktop environment.";
  };
  config = mkIf cfg.enable {
    home.packages = [
      pkgs.rkvm
    ];
  };
}

