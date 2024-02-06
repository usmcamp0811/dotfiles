{ options, config, lib, pkgs, ... }:

with lib;
with lib.campground;
let cfg = config.campground.apps.signal;
in
{
  options.campground.apps.signal = with types; {
    enable = mkBoolOpt false "Whether or not to enable signal.";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      signal-desktop
    ];
  };
}
