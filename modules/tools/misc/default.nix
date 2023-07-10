{ options, config, lib, pkgs, ... }:

with lib;
with lib.internal;
let cfg = config.campground.tools.misc;
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
    ];
  };
}
