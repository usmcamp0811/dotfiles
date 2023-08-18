{ options, config, lib, pkgs, ... }:

with lib;
with lib.campground;
let
  cfg = config.campground.apps.emacs;
in
{
  options.campground.apps.emacs = with types; {
    enable = mkBoolOpt false "Whether or not to enable Emacs.";
  };

  config = mkIf (cfg.enable || cfg.spacemacs) {
    environment.systemPackages = mkIf cfg.enable (with pkgs; [emacs29]);
  };
}
