{ inputs, pkgs, options, config, lib, ... }:
with lib;
with lib.campground;
let cfg = config.campground.desktop.addons.wlsunset;
in {
  options.campground.desktop.addons.wlsunset = with types; {
    enable =
      mkBoolOpt false "Whether to enable wlsunset in the desktop environment.";
  };
  config = mkIf cfg.enable { home.packages = with pkgs; [ wlsunset ]; };
}
