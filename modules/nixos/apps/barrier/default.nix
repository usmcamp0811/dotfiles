{ options, config, lib, pkgs, ... }:

with lib;
with lib.campground;
let cfg = config.campground.apps.barrier;
in {
  options.campground.apps.barrier = with types; {
    enable = mkBoolOpt false "Whether or not to enable barrier.";
  };

  config =
    mkIf cfg.enable { environment.systemPackages = with pkgs; [ barrier ]; };
}
