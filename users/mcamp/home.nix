{ config, pkgs, lib, ... }:

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
  #  imports = map (n: "${./apps}/${n}") (builtins.attrNames (builtins.readDir ./apps));
  imports = [
    ./apps/brave.nix
    ./apps/firefox.nix
  ];


  xsession.windowManager.command = ''
    ${pkgs.dunst}/bin/dunst &
    ${config.xsession.windowManager.command}
    ${pkgs.ckb-next}/bin/ckb-next -b &
    ${pkgs.go-sct}/bin/sct &
  '';

  home.file = { };

  home.sessionVariables = { };
}

