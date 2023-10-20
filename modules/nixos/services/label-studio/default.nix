{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
let
  cfg = config.campground.services.label-studio;
  inherit (pkgs.campground) label-studio;
in
{
  options.campground.services.label-studio = with types; {
    enable = mkBoolOpt false "Enable label-studio;";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      label-studio
    ];

  };
}
