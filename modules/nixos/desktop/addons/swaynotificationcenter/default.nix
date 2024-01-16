{ options, config, lib, pkgs, ... }:

with lib;
with lib.campground;
let cfg = config.campground.desktop.addons.swaynotificationcenter;
in
{
  options.campground.desktop.addons.swaynotificationcenter = with types; {
    enable = mkBoolOpt false "Whether to enable swaynotificationcenter in the desktop environment.";
  };

  config = mkIf cfg.enable { 
    environment.systemPackages = with pkgs; [
      swaynotificationcenter
      libnotify
    ];

    campground.home = {
      configFile."swaync/" = {
        source = lib.cleanSourceWith {
          src = lib.cleanSource ./config/.;
        };

        recursive = true;
      };
    };
  };
}
