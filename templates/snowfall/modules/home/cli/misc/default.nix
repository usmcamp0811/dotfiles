{ config, lib, pkgs, ... }:
with lib;
with lib.namespace-change-me;
let cfg = config.namespace-change-me.cli.misc;
in {
  options.namespace-change-me.cli.misc = with types; {
    enable = mkBoolOpt false "Whether or not to misc cli programs.";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      nurl
      ripgrep-all
      ripgrep
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
      zig
      btop
      deno
      devour
      neovim
    ];
  };
}
