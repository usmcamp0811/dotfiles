{ options, config, lib, pkgs, ... }:

with lib;
with lib.campground;
let
  cfg = config.campground.suites.gaming;
in
{
  options.campground.suites.gaming = with types; {
    enable = mkBoolOpt false "Whether or not to enable gaming configuration.";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [
      pkgs.lutris
      pkgs.minecraft
      pkgs.discord
      pkgs.steam
      pkgs.prismlauncher
      pkgs.mangohud
      # pkgs.campground.list-iommu
    ];

    campground = {
      cli-apps = {
        # flake = enabled;
      };

      apps = {
        barrier = enabled;
      };

      tools = {
        # git = enabled;
        # misc = enabled;
        # julia = enabled;
        # python = enabled;
        # nvim = enabled;
        # fup-repl = enabled;
        # comma = enabled;
        # nix-ld = enabled;
        # bottom = enabled;
      };

      hardware = {
        # audio = enabled;
        # storage = enabled;
        # networking = enabled;
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
        # keyring = enabled;
      };

      system = {
        # boot = enabled;
        # fonts = enabled;
        # locale = enabled;
        # time = enabled;
        # xkb = enabled;
      };
    };
  };
}
