{ options, config, lib, pkgs, ... }:
with lib;
with lib.campground;
let cfg = config.campground.cli.misc;
in {
  options.campground.cli.misc = with types; {
    enable = mkBoolOpt false "Whether or not to misc cli programs.";
  };

  config = mkIf cfg.enable {

    campground.cli.aliases = {

      ls = "${pkgs.lsd}/bin/lsd --group-dirs first $@";
      la = "${pkgs.lsd}/bin/lsd -laF --group-dirs first $@";
      lt = "${pkgs.lsd}/bin/lsd --tree --depth 3 $@";
      cat = "${pkgs.bat}/bin/bat $@";
      pcat = "${pkgs.bat}/bin/bat -p $@";
      grep = "${pkgs.gnugrep}/bin/grep --color=auto $@";

      zathura = "${pkgs.devour}/bin/devour ${pkgs.zathura}/bin/zathura $@";

    };
    home.packages = with pkgs; [
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
