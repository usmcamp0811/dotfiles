{ options, config, lib, pkgs, ... }:

with lib;
with lib.campground;
let
  cfg = config.campground.suites.common;
in
{
  options.campground.suites.common = with types; {
    enable = mkBoolOpt false "Whether or not to enable common configuration.";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [
    ];

    campground = {
      nix = {
        enable = true;
      };

      cache = {
        public = enabled;
        campground = enabled;
      };

      cli-apps = {
        flake = enabled;
      };

      tools = {
        git = enabled;
        misc = enabled;
        nix-output-monitor = enabled;
      };

      hardware = {
        audio = enabled;
        networking = enabled;
      };

      services = {
        openssh = enabled;
      };

      security = {
        keyring = enabled;
      };

      system = {
        boot = enabled;
        fonts = enabled;
        locale = enabled;
        time = enabled;
        xkb = enabled;
      };
    };
  };
}
