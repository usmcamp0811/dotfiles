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
      # pkgs.campground.list-iommu
    ];

    campground = {
      nix = enabled;

      cache.public = enabled;

      cli-apps = {
        flake = enabled;
      };

      tools = {
        git = enabled;
        misc = enabled;
        julia = enabled;
        python = enabled;
        # nvim = enabled;
        # fup-repl = enabled;
        # comma = enabled;
        # nix-ld = enabled;
        # bottom = enabled;
      };

      hardware = {
        audio = enabled;
        # storage = enabled;
        networking = enabled;
      };

      services = {
        # printing = enabled;
        openssh = enabled;
        # ldap-client = enabled;
        # tailscale = enabled;
      };

      security = {
        # gpg = enabled;
        # doas = enabled;
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
