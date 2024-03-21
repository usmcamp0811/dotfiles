{ config, lib, options, pkgs, ... }:
with lib;
with lib.campground;
let cfg = config.campground.desktop.addons.swappy;
in {
  options.campground.desktop.addons.swappy = {
    enable =
      mkBoolOpt false "Whether to enable Swappy in the desktop environment.";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [ swappy ];

    campground.home = {
      configFile."swappy/config".source = ./config;
      file."Pictures/screenshots/.keep".text = "";
    };
  };
}
