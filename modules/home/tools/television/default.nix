{ options, config, lib, pkgs, ... }:
with lib;
with lib.campground;
let cfg = config.campground.tools.television;
in {
  options.campground.tools.television = with types; {
    enable = mkBoolOpt false "Whether or not to enable common Television.";
  };

  config = mkIf cfg.enable { home.packages = with pkgs; [ television ]; };
}
