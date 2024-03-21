{ config, lib, pkgs, ... }:

let
  cfg = config.campground.tools.icehouse;

  inherit (lib) mkEnableOption mkIf;
in {
  options.campground.tools.icehouse = { enable = mkEnableOption "Icehouse"; };

  config = mkIf cfg.enable {
    environment.systemPackages = [ pkgs.snowfallorg.icehouse ];
  };
}
