{ options, config, lib, pkgs, ... }:

with lib;
with lib.campground;
let
  cfg = config.campground.apps.onepass;

in
{
  options.campground.apps.onepass = with types; {
    enable = mkBoolOpt false "Whether or not to enable 1Password and 1Password-cli.";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [ _1password-gui _1password ];
    programs = {
      _1password-gui = {
        enable = true;
        polkitPolicyOwners = [config.campground.user.name];
      };
      _1password.enable = true;
    };
  };
}
