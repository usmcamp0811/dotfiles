{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
let
  cfg = config.campground.services.lable-studio;
in
{
  options.campground.services.lable-studio = with types; {
    enable = mkBoolOpt false "Enable label-studio;";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      label-studio
    ];

  };
}
