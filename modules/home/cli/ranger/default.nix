{ options, config, pkgs, lib, ... }:

with lib;
with lib.campground;
let 
  cfg = config.campground.cli.ranger;
in
{
  options.campground.cli.ranger = {
    enable = mkEnableOption "Ranger";
  };

  config = mkIf cfg.enable {
    programs.ranger = {
      enable = true;
    };
    home.file = { 
      ".config/ranger".source = ./configs;
    };
  };
}
