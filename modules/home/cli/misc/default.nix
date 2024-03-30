{ options, config, lib, pkgs, ... }:

with lib;
with lib.campground;
let cfg = config.campground.cli.misc;
in {
  options.campground.cli.misc = with types; {
    enable = mkBoolOpt false "Whether or not to misc cli programs.";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      fzf
      killall
      unzip
      file
      jq
      clac
      wget
      ripgrep
      bat
      lsd
      rsync
      tldr
      gcc
      clang
      zig
      btop
      deno
      devour
      neovim
    ];
  };
}

