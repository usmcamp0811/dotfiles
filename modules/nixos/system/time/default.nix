{ options
, config
, lib
, ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.system.time;
in
{
  options.fmf.system.time = with types; {
    enable =
      mkBoolOpt false "Whether or not to configure timezone information.";
    TZ = mkOpt str "America/Chicago" "Timezone to set for system";
  };

  config = mkIf cfg.enable { time.timeZone = cfg.TZ; };
}
