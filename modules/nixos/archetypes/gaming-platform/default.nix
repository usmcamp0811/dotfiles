{ options
, config
, lib
, ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.archetypes.gaming-platform;
in
{
  options.fmf.archetypes.gaming-platform = with types; {
    enable =
      mkBoolOpt false "Whether or not to enable the gaming-platform archetype.";
  };

  config = mkIf cfg.enable {
    fmf = {
      suites = {
        common = enabled;
        desktop = enabled;
        gaming = enabled;
        # development = enabled;
        # art = enabled;
        # video = enabled;
        # social = enabled;
        # media = enabled;
      };

      # tools = {
      #   # appimage-run = enabled;
      # };
    };
  };
}
