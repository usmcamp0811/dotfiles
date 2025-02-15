{ options, config, lib, pkgs, ... }:
with lib;
with lib.campground;
let cfg = config.campground.tools.beets;

in {
  options.campground.tools.beets = with types; {
    enable = mkBoolOpt false "Whether or not to enable Remmina.";
  };

  config = mkIf cfg.enable {
    # TOOD: Auto configure 
    home.packages = with pkgs; [ remmina ];

  };
}
