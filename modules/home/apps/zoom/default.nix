{ lib, config, pkgs, ... }:

let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.campground.apps.zoom;
in
{
  options.campground.apps.zoom = {
    enable = mkEnableOption "zoom";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      zoom-us
    ];
  };
}
