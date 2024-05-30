{
  options,
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.campground; let
  cfg = config.campground.apps.webcord;
in {
  options.campground.apps.webcord = with types; {
    enable = mkBoolOpt false "Whether or not to enable webcord.";
  };

  config = mkIf cfg.enable {home.packages = with pkgs; [webcord];};
}
