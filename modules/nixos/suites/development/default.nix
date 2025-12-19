{ options
, config
, lib
, ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.suites.development;
in
{
  options.fmf.suites.development = with types; {
    enable =
      mkBoolOpt false
        "Whether or not to enable common development configuration.";
  };

  config = mkIf cfg.enable {
    fmf = {
      apps = {
        k9s = enabled;
        virtmanager = enabled;
      };
      tools = {
        git = enabled;
        misc = enabled;
        # julia = enabled;
        # python = enabled;
      };
    };
  };
}
