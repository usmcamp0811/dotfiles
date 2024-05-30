{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
let cfg = config.campground.services.netbird;
in {
  options.campground.services.netbird = with types; {
    enable = mkBoolOpt false "Enable Netbird;";
  };

  config = mkIf cfg.enable { services.netbird.enable = true; };
}
