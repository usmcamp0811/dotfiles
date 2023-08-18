{ options, config, pkgs, lib, ... }:

with lib;
with lib.campground;
let cfg = config.campground.system.time;
in
{
  options.campground.system.time = with types; {
    enable =
      mkBoolOpt false "Whether or not to configure timezone information.";
  };

  config = mkIf cfg.enable { time.timeZone = "America/Chicago"; };
}
