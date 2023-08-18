inputs@{ options, config, lib, pkgs, ... }:

with lib;
with lib.campground;
let
  cfg = config.campground.cli-apps.flake;
in
{
  options.campground.cli-apps.flake = with types; {
    enable = mkBoolOpt false "Whether or not to enable flake.";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      # snowfallorg.flake
    ];
  };
}

