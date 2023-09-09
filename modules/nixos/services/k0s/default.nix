{ lib, config, pkgs, ... }:
with lib;
with lib.campground;
let
  cfg = config.campground.services.k0s;
  inherit (pkgs.campground) k0s;
in
{
  options.campground.services.k0s = with types; {
    enable = mkBoolOpt false "Enable k0s;";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      k0s
      k0sctl
    ];
  };
}
