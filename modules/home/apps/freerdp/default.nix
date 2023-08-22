{ lib, config, pkgs, ... }:

let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.campground.apps.freerdp;
in
{
  options.campground.apps.freerdp = {
    enable = mkEnableOption "freerdp";
  };

  config = mkIf cfg.enable {
    programs.freerdp = {
      enable = true;
    };
  };
}
