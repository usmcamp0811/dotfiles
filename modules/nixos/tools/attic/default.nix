{ config
, lib
, pkgs
, ...
}:
with lib;
with lib.campground; let
  cfg = config.campground.tools.attic;
in
{
  options.campground.tools.attic = { enable = mkEnableOption "Attic"; };

  config =
    mkIf cfg.enable { environment.systemPackages = with pkgs; [ attic-client ]; };
}
