{ options
, config
, lib
, ...
}:
with lib;
with lib.campground; let
  cfg = config.campground.archetypes.gaming-platform;
in
{
  options.campground.archetypes.gaming-platform = with types; {
    enable =
      mkBoolOpt false "Whether or not to enable the gaming-platform archetype.";
  };

  config = mkIf cfg.enable {
    campground = {
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
