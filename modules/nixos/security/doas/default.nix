{ options, config, pkgs, lib, ... }:

with lib;
with lib.campground;
let cfg = config.campground.security.doas;
in
{
  options.campground.security.doas = {
    enable = mkBoolOpt false "Whether or not to replace sudo with doas.";
  };

  config = mkIf cfg.enable {
    # Disable sudo
    security.sudo.enable = false;

    # Enable and configure `doas`.
    security.doas = {
      enable = true;
      extraRules = [{
        users = [ config.campground.user.name ];
        cmd = "/run/current-system/sw/bin/nixos-rebuild";
        noPass = true;
        keepEnv = true;
      }];
    };

    # Add an alias to the shell for backward-compat and convenience.
    environment.shellAliases = { sudo = "doas"; };
  };
}
