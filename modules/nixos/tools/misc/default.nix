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
    include-gui-tools = mkBoolOpt true "Whether to include GUI tools like flameshot (disable for headless servers).";
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
      neovim
      devour
      usbutils
      pciutils
      fastfetch
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
    ] ++ lib.optionals cfg.include-gui-tools [
      flameshot
    ];
  };
}
