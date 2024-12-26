{ options, config, inputs, lib, pkgs, ... }:
with lib;
with lib.campground;
let
  cfg = config.campground.tools.misc;
  flake-src = ../../../..;
  configs = inputs.self.nixosConfigurations;
  sys = lib.campground.findVaultPathsAndFields configs.butler.config.campground;
in
{
  options.campground.tools.misc = with types; {
    enable = mkBoolOpt false "Whether or not to enable common utilities.";
  };

  config = mkIf cfg.enable {
    campground.home.configFile."wgetrc".text = "";
    campground.home.configFile."tst.json".text = builtins.toJSON sys;

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
      sbomnix
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
