{ options, config, lib, pkgs, ... }:
with lib;
with lib.campground;
let cfg = config.campground.tools.julia;
in {
  options.campground.tools.julia = with types; {
    enable = mkBoolOpt false "Whether or not to enable common Julia.";
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      pkgs.campground.julia
      pkgs.campground.julia.jupyter-console
      pkgs.campground.julia.jupyter-qtconsole
    ];
  };
}
