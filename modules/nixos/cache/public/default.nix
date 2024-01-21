{ config, lib, ... }:

with lib;
with lib.campground;
let
  cfg = config.campground.cache.public;
in
{
  options.campground.cache.public = {
    enable = mkEnableOption "NixOS public cache";
  };
  config = mkIf cfg.enable {
    campground.nix.extra-substituters = {
      "https://cache.nixos.org/".key = "public:QUkZTErD8fx9HQ64kuuEUZHO9tXNzws7chV8qy/KLUk=";
    };
  };
}

