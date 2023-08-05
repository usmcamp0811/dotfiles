{ config, pkgs, ... }:

let
  importAll = dir: 
    let
      allFiles = builtins.attrNames (builtins.readDir dir);
      nixFiles = builtins.filter (name: builtins.hasSuffix ".nix" name) allFiles;
    in
      map (file: import "${dir}/${file}") nixFiles;
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

  # Use the function to import all .nix files from the apps directory
  imports = importAll ./apps;

  campground.firefox.enable = true;
  # campground.brave.enable = true;

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

