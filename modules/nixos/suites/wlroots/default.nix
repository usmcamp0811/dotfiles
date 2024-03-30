{ config, inputs, system, lib, options, pkgs, ... }:
with lib;
with lib.campground;
let
  inherit (inputs) nixpkgs-wayland;

  cfg = config.campground.suites.wlroots;
in {
  options.campground.suites.wlroots = {
    enable =
      mkBoolOpt false "Whether or not to enable common wlroots configuration.";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      cliphist
      swayimg
      nixpkgs-wayland.packages.${system}.wdisplays
      wl-screenrec
      nixpkgs-wayland.packages.${system}.wl-clipboard
      wlr-randr
      # Not really wayland specific, but I don't want to make a new module for it
      brightnessctl
      glib # for gsettings
      gtk3.out # for gtk-launch
      playerctl
    ];

    campground = {
      # cli-apps = {
      #   wshowkeys = enabled;
      # };

      desktop.addons = {
        # electron-support = enabled;
        # swappy = enabled;
        swaylock = enabled;
        swaynotificationcenter = enabled;
      };
    };

    programs = {
      nm-applet.enable = true;
      xwayland.enable = true;
    };
  };
}
