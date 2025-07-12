{ options
, config
, lib
, pkgs
, ...
}:
with lib;
with lib.campground; let
  cfg = config.campground.apps.thunderbird;
in
{
  options.campground.apps.thunderbird = with types; {
    enable = mkBoolOpt false "Whether or not to enable Thunderbird for email.";
  };

  config = mkIf cfg.enable {
    programs.thunderbird.enable = true;
    programs.thunderbird.profiles.default = {
      isDefault = true;
      settings = { };
    };
  };
}
