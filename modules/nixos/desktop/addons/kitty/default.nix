{ options, config, lib, pkgs, ... }:

with lib;
with lib.campground;
let cfg = config.campground.desktop.addons.kitty;
in {
  options.campground.desktop.addons.kitty = with types; {
    enable =
      mkBoolOpt false "Whether to enable Kitty in the desktop environment.";
  };

  config =
    mkIf cfg.enable { environment.systemPackages = with pkgs; [ kitty ]; };
}

