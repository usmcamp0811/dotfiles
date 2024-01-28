{ options, config, lib, pkgs, ... }:

with lib;
with lib.campground;
let cfg = config.campground.desktop.addons.swaylock;
in
{
  options.campground.desktop.addons.swaylock = with types; {
    enable = mkBoolOpt false "Swaylock fix so it works with pam";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [ swaylock-effects ];
    security.pam.services.swaylock = { };
  };
}
