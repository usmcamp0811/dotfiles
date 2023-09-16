{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
let
  cfg = config.campground.services.docker;
in
{
  options.campground.services.docker = with types; {
    enable = mkBoolOpt false "Enable Docker;";
  };

  config = mkIf cfg.enable {
    virtualisation.docker.enable = true;

  };
}
