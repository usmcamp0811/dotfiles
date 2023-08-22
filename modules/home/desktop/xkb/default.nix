{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.home.campground.system.xkb;
in
{
  options.home.campground.system.xkb = with lib.types; {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether or not to configure xkb.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.keyboard = {
      layout = "us";
      xkbOptions = "caps:escape";
    };
  };
}
