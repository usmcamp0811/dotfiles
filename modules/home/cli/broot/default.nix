{ options, config, lib, pkgs, ... }:

with lib;
with lib.campground;
let
  cfg = config.campground.cli.broot;
in
{
  options.campground.cli.broot = with types; {
    enable = mkBoolOpt false "Whether or not to enable K9s.";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      broot
    ];
  };
}

