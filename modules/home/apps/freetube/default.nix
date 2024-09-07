{ lib, config, ... }:
let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.campground.apps.freetube;
in
{
  options.campground.apps.freetube = {
    enable = mkEnableOption "freetube";
  };

  config = mkIf cfg.enable {
    programs.freetube = {
      enable = true;
    };
  };
}
