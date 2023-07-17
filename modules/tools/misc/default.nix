{ options, config, lib, pkgs, agenix, ... }:

with lib;
with lib.internal;
let 
  cfg = config.campground.tools.misc;
in
{
  options.campground.tools.misc = with types; {
    enable = mkBoolOpt false "Whether or not to enable common utilities.";
  };

  config = mkIf cfg.enable {
    campground.home.configFile."wgetrc".text = "";

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
      neovim
      ranger
      lsd
      git
      rsync
      tldr
      gcc
      clang
      zig
    ];

    imports = [
      agenix.nixosModules.age
    ];
  };
}

