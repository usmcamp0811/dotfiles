{ options, config, inputs, lib, pkgs, ... }:
with lib;
with lib.fmf;
let
  cfg = config.fmf.tools.misc;
  flake-src = ../../../..;
in
{
  options.fmf.tools.misc = with types; {
    enable = mkBoolOpt false "Whether or not to enable common utilities.";
  };

  config = mkIf cfg.enable {
    fmf.home.configFile."wgetrc".text = "";

    environment.systemPackages = with pkgs; [
      fzf
      killall
      unzip
      file
      jq
      clac
      wget
      ripgrep
      bat
      ranger
      lsd
      git
      rsync
      tldr
      gcc
      clang
      zig
      btop
      deno
      flameshot
      neovim
      devour
      usbutils
      pciutils
      neofetch
      libnotify
      # sbomnix
      bash
      lsof
      hwinfo
      traceroute
      gptfdisk
      parted
      tmux
      cntr
      glibc
      smartmontools
      lshw
      borgbackup
      yt-dlp
    ];
  };
}
