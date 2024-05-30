{ options
, config
, lib
, ...
}:
with lib;
with lib.campground; let
  cfg = config.campground.system.time;
in
{
  options.campground.system.time = with types; {
    enable =
      mkBoolOpt false "Whether or not to configure timezone information.";
    TZ = mkOpt str "America/Chicago" "Timezone to set for system";
  };

  config = mkIf cfg.enable { time.timeZone = cfg.TZ; };
}
