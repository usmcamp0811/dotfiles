{ options, config, lib, pkgs, ... }:

with lib;
with lib.campground;
let cfg = config.campground.desktop.addons.kitty;
in
{
  options.campground.desktop.addons.kitty = with types; {
    enable =
      mkBoolOpt false "Whether to enable Kitty in the desktop environment.";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [ kitty ];

    # TODO: look at the nix config options for kitty.. maybe we can do away with these files
    campground.home.configFile."kitty/current-theme.conf".source = ./current-theme.conf;
    campground.home.configFile."kitty/kitty.conf".source = ./kitty.conf;
  };
}

