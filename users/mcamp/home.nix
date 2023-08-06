{ config, pkgs, ... }:

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
  imports = map (n: "${./apps}/${n}") (builtins.attrNames (builtins.readDir ./apps));

  options = {
    campground = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule ({ name, ... }: {
        options.enable = lib.mkEnableOption name;
      }));
      default = {};
      description = "Campground programs";
    };
  };

#  campground.firefox.enable = true;
#  campground.brave.enable = true;

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

