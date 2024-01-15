{ options, config, lib, pkgs, ... }:

with lib;
with lib.campground;
let cfg = config.campground.desktop.addons.wofi;
in
{
  options.campground.desktop.addons.wofi = with types; {
    enable = mkBoolOpt false "Whether to enable the Wofi in the desktop environment.";
  };

  config = mkIf cfg.enable { 
    environment.systemPackages = with pkgs; [
      wofi
      wofi-emoji
    ];

    campground.home.configFile = {
      "wofi/config".source = ./config;
      "wofi/style.css".source = ./style.css;
    };

  };
}
