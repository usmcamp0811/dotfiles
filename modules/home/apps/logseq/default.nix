{ lib, config, pkgs, ... }:

let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.campground.apps.logseq;
in
{
  options.campground.apps.logseq = {
    enable = mkEnableOption "logseq";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      logseq
    ];
  };
}
