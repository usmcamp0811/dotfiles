{ options, config, lib, pkgs, ... }:

with lib;
with lib.campground;
let cfg = config.campground.tools.protonup-qt;
in {
  options.campground.tools.protonup-qt = with types; {
    enable = mkBoolOpt false "Whether or not to enable protonup-qt.";
  };

  config = mkIf cfg.enable {

    home.packages = with pkgs; [ protonup-qt ];
  };
}
