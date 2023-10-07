{ options, config, lib, pkgs, ... }:

with lib;
with lib.campground;
let 
  cfg = config.campground.tools.emoji-picker;
  inherit (pkgs.campground) emoji-picker;
in
{
  options.campground.tools.emoji-picker = with types; {
    enable = mkBoolOpt false "Whether or not to enable emoji-picker.";
  };
  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      emoji-picker
    ];
  };
}
