{
  config,
  inputs,
  system,
  lib,
  options,
  pkgs,
  ...
}:
with lib;
with lib.fmf; let
  inherit (inputs) nixpkgs-wayland;

  cfg = config.fmf.suites.wlroots;
in {
  options.fmf.suites.wlroots = {
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

    fmf = {
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
