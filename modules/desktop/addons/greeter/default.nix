{ options, config, lib, pkgs, ... }:

with lib;
with lib.internal;
let cfg = config.campground.desktop.addons.rofi;
in
{
  options.campground.desktop.addons.greeter = with types; {
    enable =
      mkBoolOpt false "Whether to enable Rofi in the desktop environment.";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [ lightdm-slick-greeter ];

    # campground.home.configFile."rofi/config.rasi".source = ./config.rasi;
  };
}

