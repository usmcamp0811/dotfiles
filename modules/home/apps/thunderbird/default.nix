{ options
, config
, lib
, pkgs
, ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.apps.thunderbird;
in
{
  options.fmf.apps.thunderbird = with types; {
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
