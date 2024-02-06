{ options, config, lib, pkgs, ... }:

with lib;
with lib.campground;
let
  cfg = config.campground.apps.onepass;

in
{
  options.campground.apps.onepass = with types; {
    enable = mkBoolOpt false "Whether or not to enable 1Password with polkitPolicyOwners.";
  };

  config = mkIf cfg.enable {
    programs = {
      _1password-gui = {
        enable = true;
        polkitPolicyOwners = [config.campground.user.name];
      };
    };
  };
}
