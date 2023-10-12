{ lib, config, pkgs, ... }:

let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.campground.apps.qutebrowser;
in
{
  options.campground.apps.qutebrowser = {
    enable = mkEnableOption "qutebrowser";
  };

  config = mkIf cfg.enable {
    home.file = builtins.attrsets.mapAttrsToList (name: path: {
      target = ".config/qutebrowser/${name}";
      source = path;
    }) (builtins.readDir ./qutebrowser);
    home.packages = with pkgs; [
      qutebrowser
    ];
  };
}
