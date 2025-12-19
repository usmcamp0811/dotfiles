{ options
, config
, lib
, ...
}:
with lib;
with lib.fmf; let
  cfg = config.fmf.apps.onepass;
in
{
  options.fmf.apps.onepass = with types; {
    enable =
      mkBoolOpt false
        "Whether or not to enable 1Password with polkitPolicyOwners.";
  };

  config = mkIf cfg.enable {
    programs = {
      _1password-gui = {
        enable = true;
        polkitPolicyOwners = [ config.fmf.user.name ];
      };
    };
  };
}
