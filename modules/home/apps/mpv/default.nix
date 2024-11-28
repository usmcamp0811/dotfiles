{ lib, pkgs, config, ... }:
let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.campground.apps.mpv;
in
{
  options.campground.apps.mpv = { enable = mkEnableOption "mpv"; };

  config = mkIf cfg.enable {

    campground.cli.aliases = {
      mpv =
        "${pkgs.devour}/bin/devour ${pkgs.mpv}/bin/mpv --script=$HOME/.config/mpv/scripts/mpv-cheatsheet.js -ao=pipewire";

    };

    programs.mpv = { enable = true; };
  };
}
