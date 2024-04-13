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
  cfg = config.campground.desktop.addons.networkmanagerapplet;
in {
  options.campground.desktop.addons.networkmanagerapplet = with types; {
    enable =
      mkBoolOpt false
      "Whether to enable networkmanagerapplet in the desktop environment.";
  };
  config = mkIf cfg.enable {home.packages = [pkgs.networkmanagerapplet];};
}
