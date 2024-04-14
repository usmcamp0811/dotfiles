{ lib
, config
, ...
}:
let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.campground.apps.mpv;
in
{
  options.campground.apps.mpv = { enable = mkEnableOption "mpv"; };

  config = mkIf cfg.enable { programs.mpv = { enable = true; }; };
}
