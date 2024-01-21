{ config, lib, ... }:

with lib;
with lib.campground;
let
  cfg = config.campground.cache.campground;
in
{
  options.campground.cache.campground = {
    enable = mkEnableOption "Campground cache";
  };
  config = mkIf cfg.enable {
    campground.nix.extra-substituters = {
      "http://reckless:8080/campground".key = "campground:kOmxjP/V7XGZvhuiKVSt1Nb3dP+JFt8rg99RD78nVec=";
    };
  };
}

