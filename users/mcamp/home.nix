{ config, pkgs, ... }:

let
  modulesPath = ./apps;
  importAllModules = dir: builtins.concatMap (name: import (dir + "/${name}/default.nix")) (builtins.attrNames (builtins.readDir dir));
in
{
  home.username = "mcamp";
  home.homeDirectory = "/home/mcamp";
  home.stateVersion = "22.11";

  nixpkgs.config.allowUnfree = true;

  home.packages = with pkgs; [
    k9s
    btop
    julia
    deno
    autorandr
    arandr
    feh
    qutebrowser
    zathura
    dunst
    go-sct
  ];

  # Import all modules from the ./modules/programs directory
  imports = importAllModules modulesPath;

  campground.firefox.enable = true;
  campground.brave.enable = true;

  xsession.windowManager.command = ''
    ${pkgs.dunst}/bin/dunst &
    ${config.xsession.windowManager.command}
    ${pkgs.ckb-next}/bin/ckb-next -b &
    ${pkgs.go-sct}/bin/sct &
  '';

  home.file = { };

  home.sessionVariables = { };

  programs.home-manager.enable = true;
}

