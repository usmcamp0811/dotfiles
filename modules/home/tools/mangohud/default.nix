{
  options,
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.campground; let
  cfg = config.campground.tools.mangohud;
in {
  options.campground.tools.mangohud = with types; {
    enable = mkBoolOpt false "Whether or not to enable mangohud.";
  };

  config = mkIf cfg.enable {home.packages = with pkgs; [mangohud];};
}
