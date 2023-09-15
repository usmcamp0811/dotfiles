{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
let
  cfg = config.campground.services.busybox;
in
{
  options.campground.services.busybox = with types; {
    enable = mkBoolOpt false "Enable Getty;";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      busybox
    ];
  };
}


