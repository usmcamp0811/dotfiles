{
  config,
  lib,
  ...
}:
with lib;
with lib.campground; let
  cfg = config.campground.cache.campground;
in {
  options.campground.cache.campground = {
    enable = mkEnableOption "Campground cache";
  };
  config = mkIf cfg.enable {
    campground.nix.extra-substituters = {
      # "https://attic.aicampground.com/campground".key = "campground:XZ6LmOgWmChUUb5ZWWn/XnTreAYaNcPTQHxUR3T3dc8=";
      "s3://nix-cache?endpoint=https://s3-api.lan.aicampground.com&region=us-east-1".key = "campground:Us1XpC1L8ruQ7UoBBfZqrQravKKTVLIijcuhJ2bK6H4=";
    };
  };
}
