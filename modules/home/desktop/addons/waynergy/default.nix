{
  inputs,
  options,
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.campground; let
  cfg = config.campground.desktop.addons.waynergy;
in {
  options.campground.desktop.addons.waynergy = with types; {
    enable =
      mkBoolOpt false "Whether to enable waynergy in the desktop environment.";
  };
  config = mkIf cfg.enable {home.packages = [pkgs.waynergy];};
}
