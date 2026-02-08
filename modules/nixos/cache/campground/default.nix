{
  config,
  lib,
  ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.cache.campground;
in {
  options.fmf.cache.campground = {
    enable = mkEnableOption "Campground cache";
  };
  config = mkIf cfg.enable {
    fmf.nix.extra-substituters = {
      "https://attic.aicampground.com/campground".key = "campground:XZ6LmOgWmChUUb5ZWWn/XnTreAYaNcPTQHxUR3T3dc8=";
    };
  };
}
