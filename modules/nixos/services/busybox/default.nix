{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
let cfg = config.campground.services.busybox;
in {
  options.campground.services.busybox = with types; {
    enable = mkBoolOpt false "Enable busybox;";
  };

  config =
    mkIf cfg.enable { environment.systemPackages = with pkgs; [ busybox ]; };
}

