{ lib, config, ... }:

let
  inherit (lib) mkEnableOption mkIf;
  inherit (lib.campground) enabled;

  cfg = config.campground.cli.home-manager;
in {
  options.campground.cli.home-manager = {
    enable = mkEnableOption "home-manager";
  };

  config = mkIf cfg.enable { programs.home-manager = enabled; };
}
