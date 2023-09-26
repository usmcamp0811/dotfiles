inputs@{ options, config, lib, pkgs, ... }:

with lib;
with lib.campground;
let
  cfg = config.campground.cli-apps.cowsay;
in
{
  options.campground.cli-apps.cowsay = with types; {
    enable = mkBoolOpt false "Whether or not to enable cowsay.";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      pkgs.cowsay
    ];
  };
}


