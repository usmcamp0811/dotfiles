{ config, lib, ... }:

with lib;
with lib.internal;
let
  cfg = config.campground.cache.public;
in
{
  options.campground.cache.public = {
    enable = mkEnableOption "Plus Ultra public cache";
  };

  config = mkIf cfg.enable {
    campground.nix.extra-substituters = {
      "https://attic.ruby.hamho.me/public".key = "public:QUkZTErD8fx9HQ64kuuEUZHO9tXNzws7chV8qy/KLUk=";
    };
  };
}

