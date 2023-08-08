{ config, lib, pkgs, ... }:
{
  home.username = "mcamp";
  home.homeDirectory = "/home/mcamp";
  home.stateVersion = "22.11";

  nixpkgs.config.allowUnfree = true;

  imports = [
    ./apps/brave.nix
    ./apps/firefox.nix
  ];

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

  services = {
    syncthing = {
      enable = true;
    };
  };

  xsession.windowManager.command = ''
    ${pkgs.dunst}/bin/dunst &
    ${config.xsession.windowManager.command}
    ${pkgs.ckb-next}/bin/ckb-next -b &
    ${pkgs.go-sct}/bin/sct &
  '';

  home.file = { };

  home.sessionVariables = { };

  programs.home-manager.enable = true;

  home.activation = {
    copyMySSHKey = lib.hm.dag.entryAfter ["writeBoundary"] ''
      cp /var/lib/vault/users/mcamp/id_ed25519 $HOME/.ssh/id_ed25519
      chmod 600 $HOME/.ssh/id_ed25519
      ${pkgs.openssh}/bin/ssh-keygen -y -f $HOME/.ssh/id_ed25519 > $HOME/.ssh/id_ed25519.pub
    '';
  };


}


