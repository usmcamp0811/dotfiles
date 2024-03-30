{ options, config, lib, pkgs, ... }:

with lib;
with lib.campground;
let cfg = config.campground.apps.prismlauncher;
in {
  options.campground.apps.prismlauncher = with types; {
    enable = mkBoolOpt false "Whether or not to enable prismlauncher.";
  };

  config = mkIf cfg.enable { home.packages = with pkgs; [ prismlauncher ]; };
}
