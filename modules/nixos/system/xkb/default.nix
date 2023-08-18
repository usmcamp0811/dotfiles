{ options, config, lib, ... }:

with lib;
with lib.campground;
let cfg = config.campground.system.xkb;
in
{
  options.campground.system.xkb = with types; {
    enable = mkBoolOpt false "Whether or not to configure xkb.";
  };

  config = mkIf cfg.enable {
    console.useXkbConfig = true;

    services.xserver = {
      layout = "us";
      xkbOptions = "caps:escape";
    };
  };
}
