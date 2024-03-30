{ options, config, lib, pkgs, ... }:

with lib;
with lib.campground;
let cfg = config.campground.tools.liquidctl;
in {
  options.campground.tools.liquidctl = with types; {
    enable = mkBoolOpt false "Whether or not to enable common DVC.";
  };

  config = mkIf cfg.enable {

    home.packages = with pkgs; [ liquidctl ];
  };
}
