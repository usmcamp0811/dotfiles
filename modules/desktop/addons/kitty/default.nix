{ options, config, lib, pkgs, ... }:

with lib;
with lib.internal;
let cfg = config.campground.desktop.addons.rofi;
in
{
  options.campground.desktop.addons.rofi = with types; {
    enable =
      mkBoolOpt false "Whether to enable Rofi in the desktop environment.";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [ kitty ];

    campground.home.configFile."kitty/kitty.conf".source = ./kitty.conf;
    campground.home.configFile."kitty/current-theme.conf".source = ./current-theme.conf;
  };
}

