{ lib
, config
, pkgs
, ...
}:
let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.campground.apps.audible-cli;
in
{
  options.campground.apps.audible-cli = { enable = mkEnableOption "audible-cli"; };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      audible-cli
      ffmpeg
      python3Packages.audible-activator
    ];
  };
}
