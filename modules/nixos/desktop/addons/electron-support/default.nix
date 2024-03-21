{ config, lib, options, ... }:
with lib;
with lib.campground;
let cfg = config.campground.desktop.addons.electron-support;
in {
  options.campground.desktop.addons.electron-support = {
    enable = mkBoolOpt false
      "Whether to enable electron support in the desktop environment.";
  };

  config = mkIf cfg.enable {
    environment.sessionVariables = { NIXOS_OZONE_WL = "1"; };

    campground.home.configFile."electron-flags.conf".source =
      ./electron-flags.conf;
  };
}
